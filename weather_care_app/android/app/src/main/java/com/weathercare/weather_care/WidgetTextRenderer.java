package com.codesoha.weathercare;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.text.TextUtils;

final class WidgetTextRenderer {
    private WidgetTextRenderer() { }

    static Bitmap line(
            Context context,
            String text,
            int fontResource,
            float textSizeDp,
            int color,
            int maxWidthDp
    ) {
        TextPaint paint = textPaint(context, fontResource, textSizeDp, color);
        int edge = Math.max(1, pixels(context, 0.5f));
        int widthLimit = Math.max(1, pixels(context, maxWidthDp));
        int textWidthLimit = Math.max(1, widthLimit - edge * 2);
        CharSequence displayed = TextUtils.ellipsize(
                text,
                paint,
                textWidthLimit,
                TextUtils.TruncateAt.END
        );
        int textWidth = Math.max(1, (int) Math.ceil(paint.measureText(displayed.toString())));
        Paint.FontMetricsInt metrics = paint.getFontMetricsInt();
        int width = Math.min(widthLimit, textWidth + edge * 2);
        int height = Math.max(1, metrics.bottom - metrics.top + edge * 2);
        Bitmap bitmap = bitmap(context, width, height);
        Canvas canvas = new Canvas(bitmap);
        canvas.drawText(displayed.toString(), edge, edge - metrics.top, paint);
        return bitmap;
    }

    static float lineWidthDp(
            Context context,
            String text,
            int fontResource,
            float textSizeDp
    ) {
        TextPaint paint = textPaint(context, fontResource, textSizeDp, Color.TRANSPARENT);
        float density = context.getResources().getDisplayMetrics().density;
        return paint.measureText(text) / density + 2f;
    }

    static Bitmap paragraph(
            Context context,
            String text,
            int fontResource,
            float textSizeDp,
            int color,
            int widthDp,
            int maxLines,
            int minLines,
            float lineSpacingDp
    ) {
        TextPaint paint = textPaint(context, fontResource, textSizeDp, color);
        int edge = Math.max(1, pixels(context, 0.5f));
        int width = Math.max(1, pixels(context, widthDp));
        int textWidth = Math.max(1, width - edge * 2);
        int lineSpacing = pixels(context, lineSpacingDp);
        StaticLayout layout = StaticLayout.Builder.obtain(text, 0, text.length(), paint, textWidth)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setBreakStrategy(Layout.BREAK_STRATEGY_SIMPLE)
                .setEllipsize(TextUtils.TruncateAt.END)
                .setEllipsizedWidth(textWidth)
                .setIncludePad(false)
                .setLineSpacing(lineSpacing, 1f)
                .setMaxLines(maxLines)
                .build();
        Paint.FontMetricsInt metrics = paint.getFontMetricsInt();
        int singleLineHeight = metrics.descent - metrics.ascent;
        int minimumHeight = singleLineHeight * minLines
                + Math.max(0, minLines - 1) * lineSpacing;
        int height = Math.max(layout.getHeight(), minimumHeight) + edge * 2;
        Bitmap bitmap = bitmap(context, width, height);
        Canvas canvas = new Canvas(bitmap);
        canvas.translate(edge, edge);
        layout.draw(canvas);
        return bitmap;
    }

    static Bitmap mixedLine(
            Context context,
            float textSizeDp,
            int color,
            int maxWidthDp,
            TextPart... parts
    ) {
        int edge = Math.max(1, pixels(context, 0.5f));
        int widthLimit = Math.max(1, pixels(context, maxWidthDp));
        TextPaint[] paints = new TextPaint[parts.length];
        float measuredWidth = 0f;
        int top = 0;
        int bottom = 0;
        for (int index = 0; index < parts.length; index++) {
            paints[index] = textPaint(
                    context,
                    parts[index].fontResource,
                    textSizeDp,
                    color
            );
            measuredWidth += paints[index].measureText(parts[index].text);
            Paint.FontMetricsInt metrics = paints[index].getFontMetricsInt();
            top = Math.min(top, metrics.top);
            bottom = Math.max(bottom, metrics.bottom);
        }
        int width = Math.min(widthLimit, Math.max(1, (int) Math.ceil(measuredWidth) + edge * 2));
        int height = Math.max(1, bottom - top + edge * 2);
        Bitmap bitmap = bitmap(context, width, height);
        Canvas canvas = new Canvas(bitmap);
        float x = edge;
        float baseline = edge - top;
        for (int index = 0; index < parts.length; index++) {
            canvas.drawText(parts[index].text, x, baseline, paints[index]);
            x += paints[index].measureText(parts[index].text);
        }
        return bitmap;
    }

    static TextPart part(String text, int fontResource) {
        return new TextPart(text, fontResource);
    }

    private static TextPaint textPaint(
            Context context,
            int fontResource,
            float textSizeDp,
            int color
    ) {
        Typeface typeface = context.getResources().getFont(fontResource);
        TextPaint paint = new TextPaint(Paint.ANTI_ALIAS_FLAG | Paint.SUBPIXEL_TEXT_FLAG);
        paint.setColor(color);
        paint.setTextSize(pixels(context, textSizeDp));
        paint.setTypeface(typeface);
        return paint;
    }

    private static Bitmap bitmap(Context context, int width, int height) {
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        bitmap.setDensity(context.getResources().getDisplayMetrics().densityDpi);
        return bitmap;
    }

    private static int pixels(Context context, float dp) {
        return Math.max(1, Math.round(
                dp * context.getResources().getDisplayMetrics().density
        ));
    }

    static final class TextPart {
        final String text;
        final int fontResource;

        TextPart(String text, int fontResource) {
            this.text = text;
            this.fontResource = fontResource;
        }
    }
}
