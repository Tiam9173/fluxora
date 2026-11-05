pub mod named_pipe {
    use tokio::net::windows::named_pipe::{PipeMode, ServerOptions};

    use crate::ipc::frame::{read_frame, write_frame};
    use crate::rpc;

    pub async fn run(pipe_name: &str) -> anyhow::Result<()> {
        let pipe_security = PipeSecurityAttributes::new()?;
        let mut first_instance = true;

        loop {
            let mut pipe = match ServerOptions::new()
                .first_pipe_instance(first_instance)
                .pipe_mode(PipeMode::Byte)
                .reject_remote_clients(true)
                .create_with_security_attributes(pipe_name, &pipe_security)
            {
                Ok(pipe) => pipe,
                Err(e) => {
                    // The first instance must be created with first_pipe_instance(true)
                    // to guarantee no other process squatted the pipe name; if that
                    // fails, abort instead of weakening the guarantee. Later failures
                    // are transient, so log and retry rather than stop the service.
                    if first_instance {
                        return Err(e.into());
                    }
                    crate::ops::logs::log_message(format!("Failed to create pipe instance: {}", e));
                    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
                    continue;
                }
            };
            first_instance = false;

            if let Err(e) = pipe.connect().await {
                crate::ops::logs::log_message(format!("IPC connect error: {}", e));
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
                continue;
            }

            tokio::spawn(async move {
                if let Err(e) = handle_connection(&mut pipe).await {
                    crate::ops::logs::log_message(format!("IPC connection error: {}", e));
                }
            });
        }
    }

    async fn handle_connection(
        pipe: &mut tokio::net::windows::named_pipe::NamedPipeServer,
    ) -> anyhow::Result<()> {
        if let Some(request) = read_frame(pipe).await? {
            let (response, stop) = rpc::handle_payload(&request).await;
            write_frame(pipe, &response).await?;

            // Signal shutdown only after the frame is on the wire. Signalling
            // earlier would race the write: the stop branch returns from
            // `run_service`, the runtime is dropped, and this task — and its
            // partially written frame — is aborted.
            if stop {
                crate::service::hub::signal_stop();
            }
        }
        Ok(())
    }

    struct PipeSecurityAttributes {
        attributes: windows::Win32::Security::SECURITY_ATTRIBUTES,
        security_descriptor: windows::Win32::Security::PSECURITY_DESCRIPTOR,
    }

    impl PipeSecurityAttributes {
        fn new() -> anyhow::Result<Self> {
            use windows::core::w;
            use windows::Win32::Security::Authorization::ConvertStringSecurityDescriptorToSecurityDescriptorW;
            use windows::Win32::Security::{PSECURITY_DESCRIPTOR, SECURITY_ATTRIBUTES};

            let mut security_descriptor = PSECURITY_DESCRIPTOR::default();
            unsafe {
                ConvertStringSecurityDescriptorToSecurityDescriptorW(
                    w!("D:P(A;;GRGW;;;SY)(A;;GRGW;;;BA)(A;;GRGW;;;AU)(A;;GRGW;;;IU)"),
                    1,
                    &mut security_descriptor,
                    None,
                )?;
            }

            Ok(Self {
                attributes: SECURITY_ATTRIBUTES {
                    nLength: std::mem::size_of::<SECURITY_ATTRIBUTES>() as u32,
                    lpSecurityDescriptor: security_descriptor.0,
                    bInheritHandle: windows::Win32::Foundation::BOOL(0),
                },
                security_descriptor,
            })
        }

        fn as_mut_ptr(&self) -> *mut std::ffi::c_void {
            (&self.attributes as *const windows::Win32::Security::SECURITY_ATTRIBUTES)
                as *mut std::ffi::c_void
        }
    }

    impl Drop for PipeSecurityAttributes {
        fn drop(&mut self) {
            unsafe {
                let _ = windows::Win32::Foundation::LocalFree(windows::Win32::Foundation::HLOCAL(
                    self.security_descriptor.0,
                ));
            }
        }
    }

    trait ServerOptionsSecurityExt {
        fn create_with_security_attributes(
            &self,
            pipe_name: &str,
            security_attributes: &PipeSecurityAttributes,
        ) -> std::io::Result<tokio::net::windows::named_pipe::NamedPipeServer>;
    }

    impl ServerOptionsSecurityExt for ServerOptions {
        fn create_with_security_attributes(
            &self,
            pipe_name: &str,
            security_attributes: &PipeSecurityAttributes,
        ) -> std::io::Result<tokio::net::windows::named_pipe::NamedPipeServer> {
            unsafe {
                self.create_with_security_attributes_raw(
                    pipe_name,
                    security_attributes.as_mut_ptr(),
                )
            }
        }
    }
}

mod frame {
    use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};

    const MAX_FRAME_SIZE: usize = 1024 * 1024;

    pub async fn read_frame<T>(stream: &mut T) -> anyhow::Result<Option<String>>
    where
        T: AsyncRead + Unpin,
    {
        let mut header = [0u8; 4];
        match stream.read_exact(&mut header).await {
            Ok(_) => {}
            Err(e) if e.kind() == std::io::ErrorKind::UnexpectedEof => return Ok(None),
            Err(e) => return Err(e.into()),
        }

        let length = u32::from_le_bytes(header) as usize;
        if length > MAX_FRAME_SIZE {
            anyhow::bail!("frame too large: {}", length);
        }

        let mut payload = vec![0u8; length];
        stream.read_exact(&mut payload).await?;
        Ok(Some(String::from_utf8(payload)?))
    }

    pub async fn write_frame<T>(stream: &mut T, payload: &str) -> anyhow::Result<()>
    where
        T: AsyncWrite + Unpin,
    {
        let bytes = payload.as_bytes();
        if bytes.len() > MAX_FRAME_SIZE {
            anyhow::bail!("frame too large: {}", bytes.len());
        }
        stream
            .write_all(&(bytes.len() as u32).to_le_bytes())
            .await?;
        stream.write_all(bytes).await?;
        stream.flush().await?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::frame::{read_frame, write_frame};
    use tokio::net::windows::named_pipe::{ClientOptions, PipeMode, ServerOptions};

    /// Unique pipe name per test process, so a stale instance can never be
    /// reused and the test never collides with the real service pipe.
    fn test_pipe_name(tag: &str) -> String {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        format!(
            r"\\.\pipe\Fluxora.Helper.Test.{}.{}.{}",
            std::process::id(),
            tag,
            nanos
        )
    }

    /// Test: a response frame written just before the server closes is still
    /// readable in full by the client.
    ///
    /// This is the reproducible replacement for the old "sleep 50ms and hope
    /// the write flushed" assumption. The service writes the stop response,
    /// then exits (closing the pipe handle); the client must still receive the
    /// complete frame, not a truncated one.
    #[tokio::test]
    async fn frame_written_before_close_is_read_in_full() {
        let name = test_pipe_name("flush");

        let mut server = ServerOptions::new()
            .pipe_mode(PipeMode::Byte)
            .create(&name)
            .expect("create pipe server");
        let mut client = ClientOptions::new()
            .pipe_mode(PipeMode::Byte)
            .open(&name)
            .expect("open pipe client");
        server.connect().await.expect("client connects");

        // A realistic stop-service response: id + ok + null data + null error.
        let payload = r#"{"version":1,"id":"stop-1","ok":true,"data":null,"error":null}"#;
        write_frame(&mut server, payload)
            .await
            .expect("write response frame");

        // Close the server immediately — this is exactly what happens when the
        // service returns and its runtime is dropped right after a stop.
        drop(server);

        let received = read_frame(&mut client)
            .await
            .expect("read should not error")
            .expect("frame should be present");

        assert_eq!(
            received, payload,
            "the response frame must arrive complete after the server closes"
        );
    }

    /// Test: a multi-frame-sized payload survives the same close-after-write
    /// path, so truncation is not just hidden by a tiny response.
    #[tokio::test]
    async fn large_frame_written_before_close_is_read_in_full() {
        let name = test_pipe_name("large");

        let mut server = ServerOptions::new()
            .pipe_mode(PipeMode::Byte)
            .create(&name)
            .expect("create pipe server");
        let mut client = ClientOptions::new()
            .pipe_mode(PipeMode::Byte)
            .open(&name)
            .expect("open pipe client");
        server.connect().await.expect("client connects");

        // 64 KiB: far past any single pipe buffer, so the write really does
        // span multiple OS-level transfers.
        let payload = "x".repeat(64 * 1024);
        write_frame(&mut server, payload.as_str())
            .await
            .expect("write large frame");

        drop(server);

        let received = read_frame(&mut client)
            .await
            .expect("read should not error")
            .expect("frame should be present");

        assert_eq!(received.len(), payload.len(), "frame length must match");
        assert_eq!(received, payload, "frame content must match byte for byte");
    }
}
