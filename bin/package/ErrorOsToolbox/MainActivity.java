package com.erroros.toolbox;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;

public class MainActivity extends Activity {
    private static final String TAG = "ErrorOSToolbox";
    private static final String KAORIOS_PKG = "com.kousei.kaorios";
    private static final String SUKISU_PKG = "com.sukisu.ultra";
    private static final String MODULE_ZIP_ASSET = "module.zip";
    private static final String SUKISU_APK_ASSET = "sukisu_ultra.apk";

    private TextView statusLine;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        statusLine = findViewById(R.id.status_line);
        findViewById(R.id.row_kaorios).setOnClickListener(v -> launchPackage(KAORIOS_PKG, "Kaorios Toolbox"));
        findViewById(R.id.row_sukisu).setOnClickListener(v -> openOrInstallSukisu());
        findViewById(R.id.row_module).setOnClickListener(v -> confirmFlashModule());
    }

    private void launchPackage(String pkg, String label) {
        PackageManager pm = getPackageManager();
        Intent launch = pm.getLaunchIntentForPackage(pkg);
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(launch);
        } else {
            Toast.makeText(this, label + " chưa được cài đặt", Toast.LENGTH_LONG).show();
            Log.w(TAG, "not installed: " + pkg);
        }
    }

    private void openOrInstallSukisu() {
        PackageManager pm = getPackageManager();
        Intent launch = pm.getLaunchIntentForPackage(SUKISU_PKG);
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(launch);
            return;
        }
        // Manager chưa cài: mở trình cài đặt từ APK đóng gói sẵn (xác nhận 1 lần).
        final File apk;
        try {
            apk = copyAsset(SUKISU_APK_ASSET, "sukisu_ultra.apk");
        } catch (IOException e) {
            Log.e(TAG, "copy asset", e);
            statusLine.setText("Lỗi chép file cài SukiSU Ultra");
            return;
        }
        Uri uri = InstallFileProvider.uriForFile(this, apk);
        Intent i = new Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            startActivity(i);
            statusLine.setText("Xác nhận cài SukiSU Ultra rồi mở lại mục này.");
        } catch (Exception e) {
            Toast.makeText(this, "Không mở được trình cài đặt", Toast.LENGTH_LONG).show();
            Log.e(TAG, "install intent", e);
        }
    }

    private void confirmFlashModule() {
        new AlertDialog.Builder(this)
                .setTitle("Flash module")
                .setMessage("Cài Zygisk Next + AlwaysStrong vào /data/adb/modules?\n"
                        + "Cần quyền root: cấp cho Error OS Toolbox trong SukiSU manager trước.")
                .setPositiveButton("Flash", (d, w) -> flashModule())
                .setNegativeButton("Huỷ", null)
                .show();
    }

    private void flashModule() {
        final File zip;
        try {
            zip = copyAsset(MODULE_ZIP_ASSET, "module.zip");
        } catch (IOException e) {
            Log.e(TAG, "copy module asset", e);
            statusLine.setText("Lỗi chép file module");
            return;
        }
        statusLine.setText("Đang flash…");
        new Thread(() -> {
            String script =
                "set -e\n"
                + "TMP=/data/local/tmp/erroros_mod\n"
                + "rm -rf \"$TMP\"; mkdir -p \"$TMP/work\" \"$TMP/mod\" || exit 91\n"
                + "cp " + shellQuote(zip.getAbsolutePath()) + " \"$TMP/bundle.zip\" || exit 92\n"
                + "cd \"$TMP/work\"\n"
                + "unzip -o -j \"$TMP/bundle.zip\" module.prop customize.sh >&2 || exit 93\n"
                + "export MODPATH=\"$TMP/mod\" TMPDIR=\"$TMP/work\" ZIPFILE=\"$TMP/bundle.zip\"\n"
                + "export ARCH=arm64 API=$(getprop ro.build.version.sdk) BOOTMODE=true KSU=true HAS32BIT=false\n"
                + "export PATH=/system/bin:$PATH\n"
                + "sh \"$TMP/work/customize.sh\" || exit 94\n"
                + "cd /; rm -rf \"$TMP\"\n"
                + "if [ -d /data/adb/modules/zygisksu ] && [ -d /data/adb/modules/tricky_store ]; then\n"
                + "  echo ERR_OK\n"
                + "else\n"
                + "  echo ERR_MISSING_MODULE_DIR\n"
                + "fi\n";
            final String out = execSu(script);
            final boolean ok = out.contains("ERR_OK");
            runOnUiThread(() -> {
                if (ok) {
                    statusLine.setText("Flash xong (zygisksu + tricky_store). Reboot để áp dụng.");
                    new AlertDialog.Builder(this)
                            .setTitle("Flash module")
                            .setMessage("Cài xong. Khởi động lại ngay để nạp module?")
                            .setPositiveButton("Reboot", (d, w) -> execSu("reboot"))
                            .setNegativeButton("Để sau", null)
                            .show();
                } else {
                    statusLine.setText("Flash thất bại — cần quyền root cho Error OS Toolbox.");
                    Log.w(TAG, "flash output: " + out);
                }
            });
        }).start();
    }

    /** Chạy script qua su. Thử các đường dẫn su phổ biến. Trả về stdout+stderr+exit code. */
    private String execSu(String script) {
        StringBuilder sb = new StringBuilder();
        String[][] candidates = {
                {"su", "-c", script},
                {"/system/bin/su", "-c", script},
        };
        for (String[] cmd : candidates) {
            try {
                Process p = Runtime.getRuntime().exec(cmd);
                drain(sb, p.getInputStream());
                drain(sb, p.getErrorStream());
                int code = p.waitFor();
                sb.append("exit=").append(code).append('\n');
                if (code == 0) {
                    return sb.toString();
                }
            } catch (IOException | InterruptedException e) {
                Log.w(TAG, "exec failed: " + cmd[0], e);
                sb.append("exec failed: ").append(cmd[0]).append('\n');
            }
        }
        return sb.toString();
    }

    private static void drain(StringBuilder sb, InputStream in) throws IOException {
        try (BufferedReader br = new BufferedReader(new InputStreamReader(in))) {
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line).append('\n');
            }
        }
    }

    private File copyAsset(String asset, String outName) throws IOException {
        File out = new File(getFilesDir(), outName);
        try (InputStream in = getAssets().open(asset);
             FileOutputStream fout = new FileOutputStream(out)) {
            byte[] buf = new byte[8192];
            int r;
            while ((r = in.read(buf)) > 0) {
                fout.write(buf, 0, r);
            }
        }
        return out;
    }

    private static String shellQuote(String s) {
        return "'" + s.replace("'", "'\\''") + "'";
    }
}
