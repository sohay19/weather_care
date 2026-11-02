package com.codesoha.weathercare.wearbridge;

import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;

/** 앱과 워치가 공유하는 서버 연결 전용 HTTPS 클라이언트. 토큰은 헤더로만 보낸다. */
public final class WearCloudHttp {
    private static final String ORIGIN = "https://weather-api.codesoha.com/api/v1/wear/";
    private WearCloudHttp() { }
    public static String newToken() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        StringBuilder result = new StringBuilder(64);
        for (byte value : bytes) result.append(String.format(java.util.Locale.ROOT, "%02x", value & 255));
        return result.toString();
    }
    public static final class Failure extends IOException {
        public final int status;
        public final String code;
        Failure(int status, String code) { super("워치 연결 요청 실패: " + status); this.status=status; this.code=code; }
    }
    public static JSONObject request(String method, String path, String token, JSONObject body) throws Exception {
        if (!path.matches("pair|claim|status|snapshot|link") || !token.matches("[0-9a-f]{64}")) throw new IOException("워치 연결 정보 오류");
        HttpURLConnection connection = (HttpURLConnection) new URL(ORIGIN + path).openConnection();
        try {
            connection.setRequestMethod(method);
            connection.setInstanceFollowRedirects(false);
            connection.setConnectTimeout(6000);
            connection.setReadTimeout(8000);
            connection.setRequestProperty("Authorization", "Bearer " + token);
            connection.setRequestProperty("Accept", "application/json");
            if (body != null) {
                byte[] data = body.toString().getBytes(StandardCharsets.UTF_8);
                if (data.length > 90 * 1024) throw new IOException("워치 자료 크기 초과");
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                connection.setFixedLengthStreamingMode(data.length);
                connection.setDoOutput(true);
                try (var output = connection.getOutputStream()) { output.write(data); }
            }
            int status = connection.getResponseCode();
            var stream = status >= 200 && status < 300 ? connection.getInputStream() : connection.getErrorStream();
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            if (stream != null) try (var input = stream) {
                byte[] chunk = new byte[4096];
                int count;
                while ((count = input.read(chunk)) != -1) {
                    if (bytes.size() + count > 128 * 1024) throw new IOException("워치 응답 크기 초과");
                    bytes.write(chunk, 0, count);
                }
            }
            JSONObject response = bytes.size() == 0 ? new JSONObject() : new JSONObject(bytes.toString(StandardCharsets.UTF_8.name()));
            if (status < 200 || status >= 300) throw new Failure(status, response.optString("error", "WEAR_REQUEST_FAILED"));
            return response;
        } finally { connection.disconnect(); }
    }
}
