package io.fluxora.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView
import io.fluxora.app.services.NotificationComponentCache
import org.json.JSONObject
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/// 通知栏「切换」卡片。
///
/// 原生 Activity，**不经过 Flutter**：Flutter 的渲染表面要么不透明（共用主
/// 引擎），要么干脆画不出内容（独立引擎），而这张卡片必须浮在别的 App 之上
/// 并且四周透明。原生视图没有这两类问题。
///
/// 数据经常驻服务的内核桥接获取，卡片独立于主界面运行。
class SwitchCardActivity : Activity() {
    private class Node(
        val name: String,
        var delay: Int,
        var testing: Boolean,
        var selected: Boolean,
    )

    private class Group(
        val name: String,
        val nodes: MutableList<Node> = mutableListOf(),
        var testUrl: String = "",
        val type: String = "Selector",
        val fixed: String = "",
    )

    private val groups = mutableListOf<Group>()
    private var selectedGroup = 0

    private val nodes: MutableList<Node>
        get() = groups.getOrNull(selectedGroup)?.nodes ?: mutableListOf()
    private var adapter: NodeAdapter? = null
    private val io = Executors.newFixedThreadPool(5)

    private lateinit var statusView: TextView

    /// 点「订阅」后要先把 App 拉起来、再关自己，见 `btn_profiles`。
    private var closeWhenBackgrounded = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setFinishOnTouchOutside(true)
        setContentView(R.layout.activity_switch_card)
        val metrics = resources.displayMetrics
        val width = minOf((440 * metrics.density).toInt(), metrics.widthPixels - (32 * metrics.density).toInt())
        window.setLayout(width, ViewGroup.LayoutParams.WRAP_CONTENT)

        statusView = findViewById(R.id.card_status)
        statusView.setOnClickListener {
            val group = groups.getOrNull(selectedGroup)
            if (group == null) loadNodes()
            else if (group.type in listOf("URLTest", "Fallback") && group.fixed.isNotEmpty()) {
                io.execute {
                    runCatching {
                        request("unlock", mapOf("group" to group.name))
                        loadNodes()
                    }.onFailure { error -> runOnUiThread { statusView.text = "恢复自动失败：${error.message}" } }
                }
            }
        }
        val list = findViewById<ListView>(R.id.node_list)
        list.layoutParams.height = minOf((360 * metrics.density).toInt(),
            (metrics.heightPixels - 260 * metrics.density).toInt().coerceAtLeast((120 * metrics.density).toInt()))
        adapter = NodeAdapter(this)
        list.adapter = adapter
        list.setOnItemClickListener { _, _, position, _ ->
            nodes.getOrNull(position)?.let { select(it) }
        }
        list.setOnItemLongClickListener { _, _, position, _ ->
            nodes.getOrNull(position)?.let { testDelay(it) }
            true
        }

        findViewById<TextView>(R.id.btn_close).setOnClickListener { finish() }
        findViewById<TextView>(R.id.btn_profiles).setOnClickListener {
            // 切订阅要重新生成配置，原生卡片做不到 —— 把用户送到 App 里。
            //
            // 这里**不能**紧接着 finish()。卡片是 singleInstance + 独立
            // taskAffinity 的独立任务，finish() 会把整个任务移除；而 MainActivity
            // 此时可能还没 resume（冷启动要建引擎、热启动要切任务）。任务先没了、
            // 新界面还没上来，系统就回到桌面 —— 表现就是「点订阅把 App 退出了」，
            // 进程随后被回收，连带把代理/VPN 服务一起带走。
            //
            // 改成：先把 App 拉起来，等卡片真正让位（onPause）再关自己。
            runCatching {
                startActivity(Intent(Intent.ACTION_MAIN).apply {
                    component = NotificationComponentCache.get(this@SwitchCardActivity)
                    addCategory(Intent.CATEGORY_LAUNCHER)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("open_profiles", true)
                })
                closeWhenBackgrounded = true
            }.onFailure {
                statusView.text = getString(R.string.action_switch) + ": " + (it.message ?: "Unable to open app")
            }
        }
        findViewById<TextView>(R.id.btn_test).setOnClickListener { testAll() }
        findViewById<TextView>(R.id.btn_locate).setOnClickListener { locateSelectedNode() }

        loadNodes()
    }

    override fun onStop() {
        super.onStop()
        // 用 onStop 而不是 onPause：A→B 的顺序是 A.onPause → B.onCreate →
        // B.onResume → A.onStop，只有在 onStop 里 App 才真正起来了。
        // 下拉通知栏只会 pause 不会 stop，所以这里不会被误触发。
        if (closeWhenBackgrounded && !isFinishing) finish()
    }

    override fun onDestroy() {
        io.shutdownNow()
        super.onDestroy()
    }

    private fun request(method: String, arguments: Map<String, String> = emptyMap()): Any? {
        val response = CompletableFuture<Any?>()
        runOnUiThread {
            if (isDestroyed || isFinishing) {
                response.cancel(false)
                return@runOnUiThread
            }
            GlobalState.requestSwitchCard(method, arguments, object : MethodChannel.Result {
                override fun success(result: Any?) { response.complete(result) }
                override fun error(code: String, message: String?, details: Any?) {
                    response.completeExceptionally(IllegalStateException(message ?: code))
                }
                override fun notImplemented() {
                    response.completeExceptionally(IllegalStateException("代理服务尚未就绪"))
                }
            })
        }
        val timeout = if (method == "delay") {
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getLong("flutter.core_test_timeout", 10_000L).coerceAtLeast(10_000L) + 3_000L
        } else 6_000L
        return response.get(timeout, TimeUnit.MILLISECONDS)
    }

    private fun loadNodes() {
        io.execute {
            // 冷启动期间，内核可能还没有发布当前配置的节点。
            var lastError: Exception? = null
            for (attempt in 0 until 8) {
            try {
                val proxies = JSONObject(request("groups") as String)
                check(proxies.length() > 0) { "代理服务尚未就绪" }
                val collected = mutableListOf<Group>()
                for (groupName in proxies.keys()) {
                    val group = proxies.optJSONObject(groupName) ?: continue
                    // 只认 Selector 会漏掉 url-test / fallback / load-balance
                    // 这些组 —— 它们同样是"可以切换的组"，只是类型不同。
                    val groupType = group.optString("type")
                    if (groupType == "Direct" || groupType == "Reject") continue
                    if (group.optJSONArray("all") == null) continue
                    val all = group.optJSONArray("all") ?: continue
                    val now = group.optString("now")
                    val entry = Group(groupName, testUrl = group.optString("testUrl"), type = groupType, fixed = group.optString("fixed"))
                    val seen = mutableSetOf<String>()
                    for (i in 0 until all.length()) {
                        val name = all.getString(i)
                        // 同一批节点会出现在多个组里，组内也可能重复 —— 按名字去重，
                        // 否则列表里同一个节点会出现好几次。
                        if (!seen.add(name)) continue
                        val delay = lastDelay(proxies.optJSONObject(name))
                        entry.nodes.add(Node(name, delay, false, name == now))
                    }
                    if (entry.nodes.isNotEmpty()) collected.add(entry)
                }
                val preferred = readPreferredGroup()
                runOnUiThread {
                    groups.clear()
                    groups.addAll(collected)
                    val index = groups.indexOfFirst { it.name == preferred }
                    selectedGroup = if (index >= 0) index else 0
                    adapter?.notifyDataSetChanged()
                    renderChips()
                    updateStatus()
                }
                return@execute
            } catch (_: InterruptedException) {
                return@execute
            } catch (e: Exception) {
                lastError = e
                if (attempt < 7) {
                    try {
                        Thread.sleep(250L + attempt * 150L)
                    } catch (_: InterruptedException) {
                        return@execute
                    }
                }
            }
            }
            runOnUiThread { statusView.text = "读取节点失败：${lastError?.message}" }
        }
    }

    /// 和 App 用同一个测速目标：分组自己的 testUrl 优先，其次 App 的全局设置。
    private fun testUrlForCurrentGroup(): String {
        groups.getOrNull(selectedGroup)?.testUrl?.takeIf { it.isNotEmpty() }?.let {
            return it
        }
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.core_test_url", null)
            ?.takeIf { it.isNotEmpty() }
            ?.let { return it }
        return "https://www.gstatic.com/generate_204"
    }

    private fun readPreferredGroup(): String? =
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.core_group", null)

    private fun updateStatus() {
        val group = groups.getOrNull(selectedGroup)
        statusView.text = when {
            group == null -> "没有可切换的节点"
            group.type in listOf("URLTest", "Fallback") && group.fixed.isNotEmpty() ->
                "${group.name} · 已锁定，点击恢复自动"
            else -> "${group.name} · ${group.nodes.size} 个节点"
        }
    }

    private fun locateSelectedNode() {
        val position = nodes.indexOfFirst { it.selected }
        if (position < 0) {
            statusView.text = "当前分组暂无选中节点"
            return
        }
        val list = findViewById<ListView>(R.id.node_list)
        list.smoothScrollToPositionFromTop(position, list.height / 3, 280)
        list.announceForAccessibility(nodes[position].name)
    }

    /// 分组切换用一排横向 chips：节点会同时出现在多个组里，平铺展开必然重复。
    private fun renderChips() {
        val row = findViewById<LinearLayout>(R.id.group_chips)
        row.removeAllViews()
        val density = resources.displayMetrics.density
        for ((index, group) in groups.withIndex()) {
            val chip = TextView(this)
            chip.text = group.name
            chip.textSize = 13f
            chip.minHeight = (48 * density).toInt()
            chip.gravity = android.view.Gravity.CENTER
            chip.maxLines = 1
            chip.ellipsize = android.text.TextUtils.TruncateAt.END
            chip.maxWidth = (140 * density).toInt()
            chip.setPadding(
                (12 * density).toInt(),
                (6 * density).toInt(),
                (12 * density).toInt(),
                (6 * density).toInt(),
            )
            chip.setTextColor(
                getColor(
                    if (index == selectedGroup) R.color.switch_card_text
                    else R.color.switch_card_sub,
                ),
            )
            if (index == selectedGroup) {
                chip.background = getDrawable(R.drawable.bg_chip_selected)
            }
            chip.setOnClickListener {
                if (selectedGroup != index) {
                    selectedGroup = index
                    adapter?.notifyDataSetChanged()
                    renderChips()
                    updateStatus()
                }
            }
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            params.marginEnd = (6 * density).toInt()
            row.addView(chip, params)
        }
    }

    /// 节点历史的最后一条就是上次测得的延迟。
    private fun lastDelay(detail: JSONObject?): Int {
        val history = detail?.optJSONArray("history") ?: return -2
        if (history.length() == 0) return -2
        val delay = history.optJSONObject(history.length() - 1)?.optInt("delay", 0) ?: 0
        return if (delay in 1..65534) delay else -1
    }

    private fun testAll() {
        val current = nodes.toList()
        if (current.isEmpty()) return
        statusView.text = "正在测速…"
        for (node in current) testDelay(node)
    }

    private fun testDelay(node: Node) {
        if (node.testing) return
        val groupName = groups.getOrNull(selectedGroup)?.name ?: return
        node.testing = true
        val testUrl = testUrlForCurrentGroup()
        runOnUiThread { adapter?.notifyDataSetChanged() }
        io.execute {
            val value = try {
                (request("delay", mapOf("node" to node.name, "url" to testUrl, "group" to groupName)) as? Number)
                    ?.toInt() ?: -1
            } catch (e: Exception) {
                -1
            }
            runOnUiThread {
                node.delay = value
                node.testing = false
                adapter?.notifyDataSetChanged()
                if (nodes.none { it.testing }) updateStatus()
            }
        }
    }

    private fun select(node: Node) {
        val group = groups.getOrNull(selectedGroup) ?: return
        if (group.type !in listOf("Selector", "URLTest", "Fallback")) {
            statusView.text = "该策略组由内核自动分配"
            return
        }
        io.execute {
            try {
                request("select", mapOf("group" to group.name, "node" to node.name))
                runOnUiThread { finish() }
            } catch (e: Exception) {
                runOnUiThread { statusView.text = "切换失败：${e.message}" }
            }
        }
    }

    private inner class NodeAdapter(private val context: Context) : BaseAdapter() {
        override fun getCount() = nodes.size
        override fun getItem(position: Int) = nodes[position]
        override fun getItemId(position: Int) = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val view = convertView
                ?: LayoutInflater.from(context).inflate(R.layout.item_switch_node, parent, false)
            val node = nodes[position]
            view.isSelected = node.selected
            val name = view.findViewById<TextView>(R.id.node_name)
            val delay = view.findViewById<TextView>(R.id.node_delay)

            // 当前选中的节点加对勾前缀：列表里没有别的视觉层级，靠这个区分。
            name.text = if (node.selected) "✓ ${node.name}" else node.name
            name.setTextColor(context.getColor(R.color.switch_card_text))

            when {
                node.testing -> {
                    delay.text = "…"
                    delay.setTextColor(context.getColor(R.color.switch_card_sub))
                }
                node.delay < 0 -> {
                    delay.text = if (node.delay == -2) "" else "不可用"
                    delay.setTextColor(context.getColor(R.color.switch_card_sub))
                }
                else -> {
                    delay.text = "${node.delay}ms"
                    delay.setTextColor(
                        when {
                            node.delay < 200 -> Color.parseColor("#3BA55D")
                            node.delay < 500 -> Color.parseColor("#D9A03A")
                            else -> Color.parseColor("#D9534F")
                        },
                    )
                }
            }
            return view
        }
    }
}
