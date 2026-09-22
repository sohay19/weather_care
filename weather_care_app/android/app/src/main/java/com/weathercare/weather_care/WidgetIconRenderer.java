package com.codesoha.weathercare;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;

import java.io.IOException;
import java.io.InputStream;

final class WidgetIconRenderer {
    private static final int NAVY = Color.rgb(37, 55, 78);
    private static final int SUN = Color.rgb(246, 183, 55);
    private static final int CLOUD = Color.rgb(249, 252, 255);
    private static final int CLOUD_BLUE = Color.rgb(118, 151, 180);
    private static final int CLOUD_DARK = Color.rgb(84, 112, 139);
    private static final int RAIN = Color.rgb(73, 143, 203);
    private static final int QUESTION = Color.rgb(118, 133, 151);
    private static final int PREPARATION_CIRCLE = Color.rgb(226, 239, 248);

    private WidgetIconRenderer() { }

    static Bitmap weather(Context context, String condition, int sizeDp, boolean monochrome) {
        int pixels = pixels(context, sizeDp);
        Bitmap bitmap = Bitmap.createBitmap(pixels, pixels, Bitmap.Config.ARGB_8888);
        bitmap.setDensity(context.getResources().getDisplayMetrics().densityDpi);
        Canvas canvas = new Canvas(bitmap);
        float size = pixels;
        Paint paint = fill();
        int cloud = monochrome ? NAVY : CLOUD;
        int accent = monochrome ? NAVY : RAIN;
        int snow = monochrome ? NAVY : Color.WHITE;

        switch (condition) {
            case "clear" -> drawSun(canvas, size * .5f, size * .5f, size * .23f,
                    monochrome ? NAVY : SUN);
            case "partlyCloudy" -> {
                drawSun(canvas, size * .63f, size * .33f, size * .17f,
                        monochrome ? NAVY : SUN);
                drawCloud(canvas, size * .48f, size * .49f, size * .76f,
                        size * .39f, cloud);
            }
            case "overcast" -> {
                drawCloud(canvas, size * .61f, size * .39f, size * .62f,
                        size * .33f, monochrome ? NAVY : CLOUD_BLUE);
                drawCloud(canvas, size * .42f, size * .57f, size * .72f,
                        size * .38f, monochrome ? NAVY : CLOUD_DARK);
            }
            case "drizzle" -> {
                drawCloud(canvas, size * .5f, size * .39f, size * .78f,
                        size * .4f, cloud);
                drawDrop(canvas, size * .42f, size * .69f, size * .026f, accent);
                drawDrop(canvas, size * .58f, size * .69f, size * .026f, accent);
                drawDrop(canvas, size * .5f, size * .84f, size * .026f, accent);
            }
            case "rain", "shower" -> {
                int rainCloud = monochrome ? NAVY
                        : "shower".equals(condition) ? CLOUD_DARK : CLOUD;
                drawCloud(canvas, size * .5f, size * .36f, size * .78f,
                        size * .4f, rainCloud);
                drawDrop(canvas, size * .32f, size * .75f, size * .058f, accent);
                drawDrop(canvas, size * .5f, size * .75f, size * .058f, accent);
                drawDrop(canvas, size * .68f, size * .75f, size * .058f, accent);
            }
            case "lightWintryMix" -> {
                drawCloud(canvas, size * .5f, size * .35f, size * .8f,
                        size * .4f, cloud);
                drawDrop(canvas, size * .24f, size * .69f, size * .026f, accent);
                drawDrop(canvas, size * .4f, size * .69f, size * .026f, accent);
                drawDrop(canvas, size * .32f, size * .84f, size * .026f, accent);
                drawSnowflake(canvas, size * .6f, size * .69f, size * .026f, snow);
                drawSnowflake(canvas, size * .76f, size * .69f, size * .026f, snow);
                drawSnowflake(canvas, size * .68f, size * .84f, size * .026f, snow);
            }
            case "wintryMix" -> {
                drawCloud(canvas, size * .5f, size * .35f, size * .8f,
                        size * .4f, cloud);
                drawDrop(canvas, size * .36f, size * .76f, size * .06f, accent);
                drawSnowflake(canvas, size * .65f, size * .77f, size * .12f, snow);
            }
            case "snowFlurry" -> {
                drawCloud(canvas, size * .5f, size * .35f, size * .8f,
                        size * .4f, cloud);
                drawSnowflake(canvas, size * .42f, size * .69f, size * .026f, snow);
                drawSnowflake(canvas, size * .58f, size * .69f, size * .026f, snow);
                drawSnowflake(canvas, size * .5f, size * .84f, size * .026f, snow);
            }
            case "snow" -> {
                drawCloud(canvas, size * .5f, size * .35f, size * .8f,
                        size * .4f, cloud);
                drawSnowflake(canvas, size * .5f, size * .77f, size * .13f, snow);
            }
            default -> {
                drawCloud(canvas, size * .5f, size * .5f, size * .8f,
                        size * .42f, cloud);
                paint.setColor(monochrome ? NAVY : QUESTION);
                paint.setTextAlign(Paint.Align.CENTER);
                paint.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
                paint.setTextSize(size * .3f);
                canvas.drawText("?", size * .52f, size * .63f, paint);
            }
        }
        return bitmap;
    }

    static Bitmap preparation(Context context, String type, int sizeDp) {
        int pixels = pixels(context, sizeDp);
        Bitmap bitmap = Bitmap.createBitmap(pixels, pixels, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        float s = pixels;
        Paint background = fill();
        background.setColor(PREPARATION_CIRCLE);
        canvas.drawCircle(s * .5f, s * .5f, s * .48f, background);

        String assetName = preparationAssetName(type);
        if (assetName != null) {
            try (InputStream input = context.getAssets().open(
                    "flutter_assets/assets/icons/" + assetName)) {
                Bitmap source = BitmapFactory.decodeStream(input);
                if (source != null) {
                    Paint imagePaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
                    RectF destination = new RectF(
                            s * .16f,
                            s * .16f,
                            s * .84f,
                            s * .84f
                    );
                    canvas.drawBitmap(source, null, destination, imagePaint);
                    source.recycle();
                    return bitmap;
                }
            } catch (IOException ignored) {
                // 번들 이미지가 없으면 기존 벡터 아이콘으로 안전하게 대체합니다.
            }
        }

        canvas.save();
        canvas.translate(s * .17f, s * .17f);
        canvas.scale(.66f, .66f);
        Paint paint = stroke(s * .075f, NAVY);
        switch (type) {
            case "UMBRELLA" -> drawUmbrella(canvas, paint, s, false);
            case "PARASOL" -> drawUmbrella(canvas, paint, s, true);
            case "HEAVY_SNOW_CAUTION" ->
                    drawSnowflake(canvas, s * .5f, s * .5f, s * .34f, NAVY);
            case "OUTERWEAR" -> drawOuterwear(canvas, paint, s);
            case "MASK" -> drawMask(canvas, paint, s);
            case "WATER" -> drawBottle(canvas, paint, s, false);
            case "SUNSCREEN" -> drawBottle(canvas, paint, s, true);
            default -> drawUmbrella(canvas, paint, s, false);
        }
        canvas.restore();
        return bitmap;
    }

    private static String preparationAssetName(String type) {
        return switch (type) {
            case "UMBRELLA" -> "prep_umbrella.png";
            case "RAINCOAT" -> "prep_raincoat.png";
            case "RAIN_BOOTS" -> "prep_rain_boots.png";
            case "PARASOL" -> "prep_parasol.png";
            case "SUNSCREEN" -> "prep_sunscreen.png";
            case "SUNGLASSES" -> "prep_sunglasses.png";
            case "WATER" -> "prep_water.png";
            case "PORTABLE_FAN" -> "prep_portable_fan.png";
            case "COOLING_ITEM" -> "prep_cooling_item.png";
            case "OUTERWEAR" -> "prep_outerwear.png";
            case "SCARF" -> "prep_scarf.png";
            case "HAND_WARMER" -> "prep_hand_warmer.png";
            case "SNOW_CHAINS" -> "prep_snow_chains.png";
            case "POWER_BANK" -> "prep_power_bank.png";
            case "WINTER_BOOTS" -> "prep_winter_boots.png";
            default -> null;
        };
    }

    static String weatherDescription(String condition) {
        return switch (condition) {
            case "clear" -> "맑음";
            case "partlyCloudy" -> "구름 많음";
            case "overcast" -> "흐림";
            case "drizzle" -> "빗방울";
            case "rain" -> "비";
            case "shower" -> "소나기";
            case "lightWintryMix" -> "빗방울과 눈날림";
            case "wintryMix" -> "비와 눈";
            case "snowFlurry" -> "눈날림";
            case "snow" -> "눈";
            default -> "날씨 정보 없음";
        };
    }

    private static void drawSun(Canvas canvas, float x, float y, float radius, int color) {
        Paint paint = stroke(Math.max(2f, radius * .12f), color);
        for (int index = 0; index < 8; index++) {
            double angle = Math.PI * index / 4d;
            float x1 = x + (float) Math.cos(angle) * radius * 1.35f;
            float y1 = y + (float) Math.sin(angle) * radius * 1.35f;
            float x2 = x + (float) Math.cos(angle) * radius * 1.72f;
            float y2 = y + (float) Math.sin(angle) * radius * 1.72f;
            canvas.drawLine(x1, y1, x2, y2, paint);
        }
        paint.setStyle(Paint.Style.FILL);
        canvas.drawCircle(x, y, radius, paint);
    }

    private static void drawCloud(
            Canvas canvas,
            float x,
            float y,
            float width,
            float height,
            int color
    ) {
        Paint paint = fill();
        paint.setColor(color);
        float left = x - width / 2f;
        float top = y - height / 2f;
        canvas.drawRoundRect(
                new RectF(left, top + height * .42f, left + width, top + height),
                height * .28f,
                height * .28f,
                paint
        );
        canvas.drawCircle(left + width * .31f, top + height * .48f, height * .29f, paint);
        canvas.drawCircle(left + width * .53f, top + height * .32f, height * .38f, paint);
        canvas.drawCircle(left + width * .75f, top + height * .53f, height * .25f, paint);
    }

    private static void drawDrop(Canvas canvas, float x, float y, float radius, int color) {
        Paint paint = fill();
        paint.setColor(color);
        Path path = new Path();
        path.moveTo(x, y - radius * 1.55f);
        path.cubicTo(
                x - radius * .45f, y - radius * .65f,
                x - radius, y,
                x - radius, y + radius * .45f
        );
        path.cubicTo(
                x - radius, y + radius * 1.1f,
                x + radius, y + radius * 1.1f,
                x + radius, y + radius * .45f
        );
        path.cubicTo(
                x + radius, y,
                x + radius * .45f, y - radius * .65f,
                x, y - radius * 1.55f
        );
        path.close();
        canvas.drawPath(path, paint);
    }

    private static void drawSnowflake(
            Canvas canvas,
            float x,
            float y,
            float radius,
            int color
    ) {
        Paint paint = stroke(Math.max(1.5f, radius * .19f), color);
        for (int index = 0; index < 3; index++) {
            double angle = Math.PI * index / 3d;
            float dx = (float) Math.cos(angle) * radius;
            float dy = (float) Math.sin(angle) * radius;
            canvas.drawLine(x - dx, y - dy, x + dx, y + dy, paint);
        }
    }

    private static void drawUmbrella(Canvas canvas, Paint paint, float s, boolean parasol) {
        RectF canopy = new RectF(s * .13f, s * .2f, s * .87f, s * .74f);
        canvas.drawArc(canopy, 190, 160, false, paint);
        Path handle = new Path();
        handle.moveTo(s * .5f, s * .47f);
        handle.lineTo(s * .5f, s * .77f);
        handle.cubicTo(s * .5f, s * .88f, s * .68f, s * .88f, s * .68f, s * .77f);
        canvas.drawPath(handle, paint);
        if (parasol) {
            canvas.drawCircle(s * .77f, s * .19f, s * .07f, paint);
            for (int index = 0; index < 4; index++) {
                double angle = Math.PI * index / 2d;
                float x1 = s * .77f + (float) Math.cos(angle) * s * .1f;
                float y1 = s * .19f + (float) Math.sin(angle) * s * .1f;
                float x2 = s * .77f + (float) Math.cos(angle) * s * .14f;
                float y2 = s * .19f + (float) Math.sin(angle) * s * .14f;
                canvas.drawLine(x1, y1, x2, y2, paint);
            }
        }
    }

    private static void drawOuterwear(Canvas canvas, Paint paint, float s) {
        Path path = new Path();
        path.moveTo(s * .38f, s * .2f);
        path.lineTo(s * .2f, s * .36f);
        path.lineTo(s * .27f, s * .55f);
        path.lineTo(s * .36f, s * .5f);
        path.lineTo(s * .33f, s * .86f);
        path.lineTo(s * .67f, s * .86f);
        path.lineTo(s * .64f, s * .5f);
        path.lineTo(s * .73f, s * .55f);
        path.lineTo(s * .8f, s * .36f);
        path.lineTo(s * .62f, s * .2f);
        path.lineTo(s * .5f, s * .34f);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawLine(s * .5f, s * .34f, s * .5f, s * .85f, paint);
    }

    private static void drawMask(Canvas canvas, Paint paint, float s) {
        RectF mask = new RectF(s * .2f, s * .3f, s * .8f, s * .72f);
        canvas.drawRoundRect(mask, s * .11f, s * .11f, paint);
        canvas.drawArc(new RectF(s * .05f, s * .32f, s * .29f, s * .73f), 90, 180, false, paint);
        canvas.drawArc(new RectF(s * .71f, s * .32f, s * .95f, s * .73f), -90, 180, false, paint);
        canvas.drawLine(s * .3f, s * .46f, s * .7f, s * .46f, paint);
        canvas.drawLine(s * .3f, s * .58f, s * .7f, s * .58f, paint);
    }

    private static void drawBottle(Canvas canvas, Paint paint, float s, boolean sunscreen) {
        RectF body = new RectF(s * .31f, s * .31f, s * .69f, s * .88f);
        canvas.drawRoundRect(body, s * .08f, s * .08f, paint);
        canvas.drawRect(s * .4f, s * .17f, s * .6f, s * .31f, paint);
        canvas.drawLine(s * .4f, s * .17f, s * .6f, s * .17f, paint);
        if (sunscreen) {
            canvas.drawCircle(s * .5f, s * .58f, s * .09f, paint);
            for (int index = 0; index < 4; index++) {
                double angle = Math.PI * index / 2d;
                float dx = (float) Math.cos(angle) * s * .14f;
                float dy = (float) Math.sin(angle) * s * .14f;
                canvas.drawLine(s * .5f + dx * .82f, s * .58f + dy * .82f,
                        s * .5f + dx, s * .58f + dy, paint);
            }
        } else {
            Path drop = new Path();
            drop.moveTo(s * .5f, s * .46f);
            drop.quadTo(s * .38f, s * .63f, s * .5f, s * .7f);
            drop.quadTo(s * .62f, s * .63f, s * .5f, s * .46f);
            canvas.drawPath(drop, paint);
        }
    }

    private static Paint fill() {
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setStyle(Paint.Style.FILL);
        return paint;
    }

    private static Paint stroke(float width, int color) {
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeWidth(width);
        paint.setColor(color);
        return paint;
    }

    private static int pixels(Context context, int dp) {
        return Math.max(1, Math.round(dp * context.getResources().getDisplayMetrics().density));
    }
}
