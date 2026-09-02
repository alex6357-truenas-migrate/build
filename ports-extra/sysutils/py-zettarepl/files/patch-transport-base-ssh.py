zettarepl @ 60ade60（13.3-era pin）与 paramiko 4.x 的兼容修复：
paramiko 4.x 删除了 DSSKey —— freecore 也做了同样的处理。

--- zettarepl/transport/base_ssh.py.orig	2023-05-10 00:27:59 UTC
+++ zettarepl/transport/base_ssh.py
@@ -155,7 +155,7 @@
         self._client = None
         saved_exception = None
         for key_class in (paramiko.RSAKey, paramiko.DSSKey, paramiko.ECDSAKey, paramiko.Ed25519Key):
-            try:
+            try:
                 return key_class.from_private_key(io.StringIO(private_key))
             except paramiko.SSHException as e:
                 saved_exception = e
