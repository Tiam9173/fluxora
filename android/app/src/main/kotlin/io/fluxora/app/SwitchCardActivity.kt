package io.fluxora.app

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.ListView
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.Executors

/// 通知栏「切换」卡片。
///
/// 原生 Activity，**不经过 Flutter**：Flutter 的渲染表面要么不透明（共用主
/// 引擎），要么干脆画不出内容（独立引擎），而这张卡片必须浮在别的 App 之上
/// 并且四周透明。原生视图没有这两类问题。
///
/// 数据直接问内核要（`/proxies`），不依赖 Flutter 引擎是否在跑 —— 内核在常驻
/// service 里，地址和密钥由 Dart 写进 SharedPreferences。
class SwitchCardActivity : Activity() {
    private class Node(
        val group: String,
        val name: String,
        var delay: Int,
        var testing: Boolean,
        var selected: Boolean,
    )

    private val nodes = mutableListOf<Node>()
    private var adapter: NodeAdapter? = null
    private var endpoint: String? = null
    private var secret: String? = null
    private val io = Executors.newFixedThreadPool(5)

    private lateinit var statusView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setFinishOnTouchOutside(true)
        setContentView(R.layout.activity_switch_card)

        statusView = findViewById(R.id.card_status)
        val list = findViewById<ListView>(R.id.node_list)
        adapter = NodeAdapter(this)
        list.adapter = adapter
        list.setOnItemClickListener { _, _, position, _ -> select(nodes[position]) }
        list.setOnItemLongClickListener { _, _, position, _ ->
            testDelay(nodes[position])
            true
        }

        findViewById<TextView>(R.id.btn_close).setOnClickListener { finish() }
        findViewById<TextView>(R.id.btn_test).setOnClickListener { testAll() }

        readEndpoint()
        loadNodes()
    }

    override fun onDestroy() {
        io.shutdownNow()
        super.onDestroy()
    }

    /// 地址和密钥有两个来源：
    /// 1. Dart 在生成配置时写下的 `core_endpoint` / `core_secret`（首选）
    /// 2. 直接读 Dart 的整份 `config`，从里面取 `external-controller`
    ///
    /// 第二条是兜底：App 刚装好、还没生成过配置时，第一条还不存在。
    private fun readEndpoint() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        var host = prefs.getString("flutter.core_endpoint", null)
        var key = prefs.getString("flutter.core_secret", null)

        if (host.isNullOrEmpty()) {
            val raw = prefs.getString("flutter.config", null)
            if (!raw.isNullOrEmpty()) {
                try {
                    val config = JSONObject(raw)
                    val controller = config.opt("external-controller")
                    host = when (controller) {
                        is JSONObject -> controller.optString("value", "")
                        is String -> controller
                        else -> ""
                    }
                    if (key.isNullOrEmpty()) {
                        key = config.optString("secret", "")
                    }
                } catch (_: Exception) {
                    // 配置格式变了也不该让卡片直接崩掉。
                }
            }
        }

        // 只写了端口时补上主机名。
        if (!host.isNullOrEmpty() && !host.contains(":")) host = "$host:9090"
        endpoint = host?.takeIf { it.isNotEmpty() }
        secret = key
    }

    private fun request(path: String, method: String = "GET", body: String? = null): String {
        val base = endpoint ?: throw IllegalStateException("内核地址未知")
        val url = URL("http://$base$path")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 3000
            readTimeout = 4000
            if (!secret.isNullOrEmpty()) {
                setRequestProperty("Authorization", "Bearer $secret")
            }
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
        }
        if (body != null) {
            conn.outputStream.use { it.write(body.toByteArray()) }
        }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() } ?: ""
        conn.disconnect()
        if (code !in 200..299) throw IllegalStateException("HTTP $code")
        return text
    }

    private fun loadNodes() {
        io.execute {
            try {
                val json = JSONObject(request("/proxies"))
                val proxies = json.getJSONObject("proxies")
                val collected = mutableListOf<Node>()
                for (groupName in proxies.keys()) {
                    val group = proxies.optJSONObject(groupName) ?: continue
                    if (group.optString("type") != "Selector") continue
                    val all = group.optJSONArray("all") ?: continue
                    val now = group.optString("now")
                    for (i in 0 until all.length()) {
                        val name = all.getString(i)
                        val detail = proxies.optJSONObject(name)
                        val delay = lastDelay(detail)
                        collected.add(Node(groupName, name, delay, false, name == now))
                    }
                }
                runOnUiThread {
                    nodes.clear()
                    nodes.addAll(collected)
                    adapter?.notifyDataSetChanged()
                    statusView.text =
                        if (nodes.isEmpty()) "没有可切换的节点" else "${nodes.size} 个节点"
                }
            } catch (e: Exception) {
                runOnUiThread {
                    statusView.text = "读取节点失败：${e.message}"
                }
            }
        }
    }

    /// `/proxies` 里每个节点带 `history`，最后一条就是上次测得的延迟。
    private fun lastDelay(detail: JSONObject?): Int {
        val history = detail?.optJSONArray("history") ?: return -1
        if (history.length() == 0) return -1
        return history.optJSONObject(history.length() - 1)?.optInt("delay", -1) ?: -1
    }

    private fun testAll() {
        statusView.text = "正在测速…"
        for (node in nodes) testDelay(node)
    }

    private fun testDelay(node: Node) {
        if (node.testing) return
        node.testing = true
        runOnUiThread { adapter?.notifyDataSetChanged() }
        io.execute {
            val value = try {
                val encoded = URLEncoder.encode(node.name, "UTF-8")
                val json = JSONObject(
                    request("/proxies/$encoded/delay?timeout=3000&url=https://www.gstatic.com/generate_204"),
                )
                json.optInt("delay", -1)
            } catch (e: Exception) {
                -1
            }
            node.delay = value
            node.testing = false
            runOnUiThread { adapter?.notifyDataSetChanged() }
        }
    }

    private fun select(node: Node) {
        io.execute {
            try {
                val encoded = URLEncoder.encode(node.group, "UTF-8")
                request(
                    "/proxies/$encoded",
                    method = "PUT",
                    body = JSONObject().put("name", node.name).toString(),
                )
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
                    delay.text = ""
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
