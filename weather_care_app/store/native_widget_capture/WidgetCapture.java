package com.codesoha.weathercare.capture;

import android.app.Instrumentation;
import android.appwidget.AppWidgetHost;
import android.appwidget.AppWidgetHostView;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProviderInfo;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Rect;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.view.View;
import android.widget.ImageView;
import java.io.File;
import java.io.FileOutputStream;
import java.lang.reflect.Method;
import java.util.Map;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONObject;

/** 실제 Provider와 AppWidgetHost를 연결한다. realWeather는 앱의 실자료를 그대로 사용한다. */
public final class WidgetCapture extends Instrumentation {
    private AppWidgetHost host;
    private AppWidgetHostView view;
    private int widgetId;
    private Bundle arguments;
    private boolean realWeather;

    @Override public void onCreate(Bundle args) {
        arguments = args;
        realWeather = "true".equals(args.getString("realWeather"));
        start();
    }

    @Override public void onStart() {
        Bundle result = new Bundle();
        int status = -1;
        SharedPreferences preferences = getTargetContext().getSharedPreferences("weather_care_widget", Context.MODE_PRIVATE);
        Map<String, ?> original = preferences.getAll();
        try {
            Context context = getTargetContext();
            getUiAutomation().adoptShellPermissionIdentity("android.permission.BIND_APPWIDGET");
            String theme = arguments.getString("theme", "light");
            // 앱의 수동 테마 설정도 촬영 테마에 맞추고 finally에서 원래 값으로 복원한다.
            preferences.edit().putString("theme_mode", theme).commit();
            int night = context.getResources().getConfiguration().uiMode & 48;
            check(night == (theme.equals("dark") ? 32 : 16), "시스템 테마 일치");
            if ("true".equals(arguments.getString("familyChecks"))) verifyFamilies(context);
            for (String family : new String[]{"small", "medium", "large"}) {
                capture(context, family, theme, 2, true);
            }
            // 1·2·3개 준비물과 긴 이름에서 남은 영역 정렬/잘림을 확인한다.
            if (!realWeather) {
                for (int count : new int[]{1, 3}) capture(context, "large", theme, count, false);
            }
            result.putString("stream", "실제 AppWidgetHost 촬영 완료\n");
        } catch (Throwable failure) {
            result.putString("stream", android.util.Log.getStackTraceString(failure));
            status = 0;
        } finally {
            if (host != null) onMain(() -> {
                host.stopListening();
                host.deleteHost();
            });
            SharedPreferences.Editor restore = preferences.edit().clear();
            for (Map.Entry<String, ?> entry : original.entrySet()) {
                String key = entry.getKey();
                Object value = entry.getValue();
                if (value instanceof String) restore.putString(key, (String) value);
                else if (value instanceof Boolean) restore.putBoolean(key, (Boolean) value);
                else if (value instanceof Integer) restore.putInt(key, (Integer) value);
                else if (value instanceof Long) restore.putLong(key, (Long) value);
                else if (value instanceof Float) restore.putFloat(key, (Float) value);
                else if (value instanceof Set) restore.putStringSet(key, (Set<String>) value);
            }
            restore.commit();
            getUiAutomation().dropShellPermissionIdentity();
        }
        finish(status, result);
    }

    /** 화면에 띄우지 않은 실제 호스트에서 세 종류를 함께 갱신하고 확장한다. */
    private void verifyFamilies(Context context) throws Exception {
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        SharedPreferences preferences = context.getSharedPreferences("weather_care_widget", Context.MODE_PRIVATE);
        String originalSnapshot = preferences.getString("snapshot", null);
        check(manager.getInstalledProviders().stream()
                .filter(item -> context.getPackageName().equals(item.provider.getPackageName())).count() == 3,
                "선택 가능한 위젯은 정확히 3종");
        String[] names = {"WeatherCareWidgetProvider", "WeatherCareMediumWidgetProvider", "WeatherCareLargeWidgetProvider"};
        AppWidgetHostView[] views = new AppWidgetHostView[3];
        int[] ids = new int[3];
        Method updateAll = Class.forName("com.codesoha.weathercare.WeatherCareWidgetProvider")
                .getDeclaredMethod("updateAll", Context.class);
        updateAll.setAccessible(true);
        onMain(() -> host = new AppWidgetHost(context, 7022));
        try {
            for (int i = 0; i < names.length; i++) {
                final int index = i;
                ComponentName component = new ComponentName(context.getPackageName(), "com.codesoha.weathercare." + names[i]);
                AppWidgetProviderInfo info = manager.getInstalledProviders().stream()
                        .filter(item -> item.provider.equals(component)).findFirst().orElseThrow();
                check(info.targetCellWidth == (i == 0 ? 2 : 4), "기본 가로 칸 수");
                check(info.targetCellHeight == (i == 2 ? 4 : 2), "기본 세로 칸 수");
                check(info.resizeMode == (i == 0 ? 0 : 3), "종류별 크기 조절 모드");
                check(info.maxResizeWidth == 0, "가로 최대값 없음");
                if (i == 1) {
                    float density = context.getResources().getDisplayMetrics().density;
                    check(Math.abs(info.maxResizeHeight - Math.round(180 * density)) <= 1, "중형 최대 높이 적용");
                } else check(info.maxResizeHeight == 0, "소형/대형 별도 최대 높이 없음");
                Bundle options = sizeOptions(i == 0 ? 156 : 334, i == 2 ? 398 : 180);
                onMain(() -> {
                    ids[index] = host.allocateAppWidgetId();
                    check(manager.bindAppWidgetIdIfAllowed(ids[index], component, options), "3종 동시 바인딩");
                    views[index] = host.createView(context, ids[index], info);
                });
            }
            onMain(() -> host.startListening());
            JSONObject snapshot = new JSONObject(preferences.getString("snapshot", "{}"));
            snapshot.put("region", "한글 갱신 확인");
            preferences.edit().putString("snapshot", snapshot.toString()).commit();
            updateAll.invoke(null, context);
            waitForIdleSync();
            Thread.sleep(500);
            for (int i = 0; i < names.length; i++) {
                final int index = i;
                onMain(() -> {
                    View region = views[index].findViewById(context.getResources().getIdentifier("widget_region", "id", context.getPackageName()));
                    check(region != null && "한글 갱신 확인".contentEquals(region.getContentDescription()), "전체 종류의 실제 자료 갱신");
                });
                if (i > 0) {
                    Bundle expanded = sizeOptions(i == 1 ? 540 : 700, i == 1 ? 289 : 650);
                    manager.updateAppWidgetOptions(ids[i], expanded);
                    android.appwidget.AppWidgetProvider receiver = (android.appwidget.AppWidgetProvider)
                            Class.forName("com.codesoha.weathercare." + names[i]).getConstructor().newInstance();
                    receiver.onAppWidgetOptionsChanged(context, manager, ids[i], expanded);
                    waitForIdleSync();
                    Thread.sleep(300);
                }
                onMain(() -> {
                    int mediumId = context.getResources().getIdentifier("widget_short_message", "id", context.getPackageName());
                    int largeId = context.getResources().getIdentifier("widget_brief", "id", context.getPackageName());
                    check((views[index].findViewById(mediumId) != null) == (index == 1), "확장 후 중형 종류 유지");
                    check((views[index].findViewById(largeId) != null) == (index == 2), "확장 후 대형 종류 유지");
                });
            }
            android.util.Log.i("WidgetFamilyVerification", "3종 등록·크기 조건·전체 갱신·확장 후 종류 유지 통과");
        } finally {
            onMain(() -> { host.stopListening(); host.deleteHost(); host = null; });
            if (originalSnapshot == null) preferences.edit().remove("snapshot").commit();
            else preferences.edit().putString("snapshot", originalSnapshot).commit();
        }
    }

    private static Bundle sizeOptions(int width, int height) {
        Bundle options = new Bundle();
        options.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, width);
        options.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, width);
        options.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, height);
        options.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, height);
        return options;
    }

    private void capture(Context context, String family, String theme, int count, boolean publish)
            throws Exception {
        int width = family.equals("small") ? 156 : 334;
        int height = family.equals("large") ? 398 : 180;
        JSONObject snapshot = new JSONObject()
                .put("region", "서울시 중구").put("refreshTime", "오전 8:00 기준")
                .put("condition", "partlyCloudy").put("currentTemperature", "18°")
                .put("apparentTemperature", "17°").put("minimumTemperature", "12°")
                .put("maximumTemperature", "22°").put("shortMessage", "우산을 챙기세요")
                .put("brief", "아침에는 선선하고 저녁에는 비가 내려요. 우산과 겉옷을 챙기세요.")
                .put("nextTime", "오전 9시").put("nextCondition", "clear")
                .put("nextTemperature", "19°");
        JSONArray items = new JSONArray();
        String[] types = {"UMBRELLA", "OUTERWEAR", "MASK"};
        String[] names = {"우산", "겉옷", "마스크"};
        if (count == 3) names[1] = "두꺼운 겉옷";
        for (int i = 0; i < count; i++) items.put(new JSONObject().put("type", types[i]).put("label", names[i]));
        snapshot.put("preparations", items);
        if (realWeather) {
            String saved = context.getSharedPreferences("weather_care_widget", Context.MODE_PRIVATE)
                    .getString("snapshot", null);
            check(saved != null, "실제 앱 날씨 자료 존재");
            snapshot = new JSONObject(saved);
            count = snapshot.optJSONArray("preparations") == null ? 0 : snapshot.getJSONArray("preparations").length();
        } else {
            context.getSharedPreferences("weather_care_widget", Context.MODE_PRIVATE).edit()
                .clear().putString("snapshot", snapshot.toString())
                .putString("refresh_url", "https://example.invalid/widget").commit();
        }
        final int preparationCount = count;
        final String expectedMinMax = "최저 " + snapshot.getString("minimumTemperature")
                + "   최고 " + snapshot.getString("maximumTemperature");
        Class<?> provider = Class.forName("com.codesoha.weathercare.WeatherCareWidgetProvider");
        Method update = provider.getDeclaredMethod("updateWidget", Context.class, AppWidgetManager.class, int.class);
        update.setAccessible(true);
        Bundle options = new Bundle();
        options.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, width);
        options.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, width);
        options.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, height);
        options.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, height);
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        String providerName = family.equals("medium") ? "WeatherCareMediumWidgetProvider"
                : family.equals("large") ? "WeatherCareLargeWidgetProvider" : "WeatherCareWidgetProvider";
        ComponentName component = new ComponentName(context.getPackageName(), "com.codesoha.weathercare." + providerName);
        AppWidgetProviderInfo info = manager.getInstalledProviders().stream()
                .filter(item -> item.provider.equals(component)).findFirst().orElseThrow();
        onMain(() -> {
            host = new AppWidgetHost(context, 7022);
            widgetId = host.allocateAppWidgetId();
            check(manager.bindAppWidgetIdIfAllowed(widgetId, component, options), "실제 위젯 바인딩");
            view = host.createView(context, widgetId, info);
            view.setPadding(0, 0, 0, 0);
            try { update.invoke(null, context, manager, widgetId); }
            catch (Exception e) { throw new RuntimeException(e); }
            host.startListening();
        });
        waitForIdleSync();
        Thread.sleep(800);
        onMain(() -> {
            float density = context.getResources().getDisplayMetrics().density;
            int w = Math.round(width * density), h = Math.round(height * density);
            view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY));
            view.layout(0, 0, w, h);
            View minimumMaximum = find(context, "widget_min_max");
            check(expectedMinMax.contentEquals(minimumMaximum.getContentDescription()), "실제 최저/최고 표시");
            ImageView refresh = (ImageView) find(context, "widget_refresh_button");
            int touchSize = Math.round(24 * density);
            check(refresh.getWidth() == touchSize && refresh.getHeight() == touchSize && refresh.isClickable(),
                    "새로고침 터치 영역 24dp 유지");
            checkRefreshSurface(refresh.getBackground(), touchSize, density);
            checkRefreshSurface(context.getDrawable(context.getResources().getIdentifier(
                    "weather_widget_refresh_background_loading", "drawable", context.getPackageName())), touchSize, density);
            check(refresh.getWidth() - refresh.getPaddingLeft() - refresh.getPaddingRight() <= Math.round(12 * density),
                    "새로고침 아이콘 축소");
            if (family.equals("medium")) {
                check(((ImageView) find(context, "widget_short_message")).getScaleType() == ImageView.ScaleType.FIT_START,
                        "짧은 브리핑 기존 왼쪽 정렬 유지");
            }
            if (family.equals("large")) {
                for (int i = 1; i <= preparationCount; i++) {
                    ImageView label = (ImageView) find(context, "widget_preparation_label_" + i);
                    View icon = find(context, "widget_preparation_icon_" + i);
                    View parent = (View) icon.getParent();
                    check(icon.getLeft() == parent.getPaddingLeft(), "아이콘 왼쪽 고정");
                    check(label.getLeft() == icon.getRight() + Math.round(4 * density), "아이콘 다음 이름 영역");
                    check(label.getRight() == parent.getWidth() - parent.getPaddingRight(), "이름이 남은 너비 사용");
                    check(label.getWidth() > 0 && label.getScaleType() == ImageView.ScaleType.CENTER_INSIDE, "이름 중앙 정렬");
                }
                check(((ImageView) find(context, "widget_brief")).getScaleType() == ImageView.ScaleType.CENTER_INSIDE,
                        "브리핑 중앙 정렬");
            }
            Bitmap bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
            view.draw(new Canvas(bitmap));
            File directory = new File(context.getExternalFilesDir(null), "store-native-widget");
            check(directory.mkdirs() || directory.isDirectory(), "촬영 폴더 생성");
            String name = publish ? theme + "-" + family : theme + "-preparations-" + preparationCount;
            try (FileOutputStream output = new FileOutputStream(new File(directory, name + ".png"))) {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, output);
            } catch (Exception e) { throw new RuntimeException(e); }
            Rect touch = new Rect(0, 0, refresh.getWidth(), refresh.getHeight());
            view.offsetDescendantRectToMyCoords(refresh, touch);
            try (FileOutputStream output = new FileOutputStream(new File(directory, name + ".json"))) {
                JSONObject geometry = new JSONObject().put("터치영역_px", new JSONArray(new int[]{
                        touch.left, touch.top, touch.right, touch.bottom}));
                output.write(geometry.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
            } catch (Exception e) { throw new RuntimeException(e); }
            bitmap.recycle();
            host.stopListening();
            host.deleteAppWidgetId(widgetId);
        });
    }

    private View find(Context context, String name) {
        View found = view.findViewById(context.getResources().getIdentifier(name, "id", context.getPackageName()));
        check(found != null, "위젯 View 존재: " + name);
        return found;
    }

    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    private static void checkRefreshSurface(Drawable background, int size, float density) {
        Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        background.setBounds(0, 0, size, size);
        background.draw(new Canvas(bitmap));
        int visible = 0;
        for (int x = 0; x < size; x++) {
            if ((bitmap.getPixel(x, size / 2) >>> 24) >= 128) visible++;
        }
        check(Math.abs(visible - Math.round(20 * density)) <= 2, "새로고침 표시 지름 20dp");
        check((bitmap.getPixel(0, size / 2) >>> 24) == 0, "터치 영역 가장자리 투명 유지");
        bitmap.recycle();
    }

    private void onMain(Runnable action) {
        Throwable[] failure = new Throwable[1];
        runOnMainSync(() -> {
            try { action.run(); }
            catch (Throwable error) { failure[0] = error; }
        });
        if (failure[0] != null) throw new RuntimeException(failure[0]);
    }
}
