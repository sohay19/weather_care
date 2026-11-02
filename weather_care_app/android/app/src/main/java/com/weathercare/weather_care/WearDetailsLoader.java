package com.codesoha.weathercare;

import android.net.Uri;
import org.json.JSONObject;
import org.json.JSONArray;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Locale;

/** 폰 백그라운드 갱신에서도 Today 상세를 같은 격자로 정규화한다. 비밀키는 폰에만 남긴다. */
final class WearDetailsLoader {
    static JSONObject load(String widgetUrl, String testKey) throws Exception {
        Uri uri = Uri.parse(widgetUrl);
        JSONObject today = get(uri.buildUpon().path("/api/v1/weather/today").build().toString(), testKey);
        JSONObject c = today.optJSONObject("current");
        if (c == null) return new JSONObject();
        JSONObject indices = today.optJSONObject("livingIndices");
        if (indices == null) indices = new JSONObject();
        JSONObject stagnation = indices.optJSONObject("airStagnation");
        String basis = c.optString("observedAt", today.optString("generatedAt", "기준 시각 없음"));
        JSONArray metrics = new JSONArray();
        metric(metrics,"체감온도", number(c, c.has("kmaApparentTemperature") && !c.isNull("kmaApparentTemperature") ? "kmaApparentTemperature" : "apparentTemperature", "°"), basis);
        metric(metrics,"습도",number(c,"humidity","%"),basis);
        metric(metrics,"자외선",number(c,"uvIndex",""),c.optString("uvObservedAt",basis));
        metric(metrics,"바람",number(c,"windSpeed","m/s"),basis);
        metric(metrics,"대기질","PM10 "+number(c,"pm10","")+"\nPM2.5 "+number(c,"pm25",""),c.optString("airQualityObservedAt",basis));
        metric(metrics,"대기정체",stagnation == null ? "자료 없음" : stagnation.optString("level","자료 없음"),stagnation == null ? basis : stagnation.optString("forecastAt",basis));
        double visibility = c.optDouble("visibilityMeters",Double.NaN);
        metric(metrics,"가시거리",Double.isFinite(visibility) ? format(visibility/1000)+"km" : "자료 없음",c.optString("visibilityObservedAt",basis));
        JSONArray pollen = indices.optJSONArray("pollen");
        StringBuilder pollenText = new StringBuilder();
        if (pollen != null) for (int i=0;i<pollen.length();i++) {
            JSONObject p=pollen.optJSONObject(i); if(p==null) continue;
            if(pollenText.length()>0) pollenText.append(" · ");
            pollenText.append(p.optString("species")).append(' ').append(p.optString("level"));
        }
        metric(metrics,"꽃가루",pollenText.length()>0 ? pollenText.toString() : "OUT_OF_SEASON".equals(indices.optString("pollenStatus")) ? "기간 외" : "자료 없음",today.optString("generatedAt",basis));
        metric(metrics,"강수량",number(c,"precipitationAmount","mm"),basis);
        metric(metrics,"적설량",number(c,"snowDepthCm","cm"),c.optString("snowDepthObservedAt",basis));
        JSONArray hours=new JSONArray();
        JSONArray raw=today.optJSONArray("hourly");
        if(raw!=null) for(int i=0;i<raw.length()&&hours.length()<24;i++) {
            JSONObject h=raw.optJSONObject(i);if(h==null) continue;
            String at=h.optString("forecastAt",h.optString("observedAt",""));
            if(at.isBlank()&&h.has("forecastDate")&&h.has("time")) at=h.getString("forecastDate")+"T"+String.format(Locale.ROOT,"%02d",h.optInt("time"))+":00:00+09:00";
            String label="--시";
            try {label=OffsetDateTime.parse(at).withOffsetSameInstant(ZoneOffset.ofHours(9)).getHour()+"시";} catch(Exception ignored) { }
            hours.put(new JSONObject().put("at",at).put("label",label).put("temperature",number(h,"temperature","°")).put("condition",condition(h.optString("skyCondition"))).put("rain",number(h,"precipitationProbability","%")));
        }
        JSONObject reasons=new JSONObject();JSONArray recs=today.optJSONArray("recommendations");
        if(recs!=null) for(int i=0;i<recs.length();i++) {JSONObject item=recs.optJSONObject(i);if(item!=null) reasons.put(item.optString("type"),item.optString("description"));}
        JSONObject result=new JSONObject().put("hours",hours).put("metrics",metrics).put("preparationReasons",reasons);
        try {
            JSONObject cmp=get(uri.buildUpon().path("/api/v1/weather/comparison/yesterday").build().toString(),testKey);
            JSONObject a=cmp.optJSONObject("current"), b=cmp.optJSONObject("comparison");
            if(cmp.optBoolean("comparisonAvailable")&&a!=null&&b!=null) {
                result.put("temperatureComparison",comparison(a,b,"temperature",""));
                result.put("apparentComparison",comparison(a,b,"apparentTemperature","체감 상 "));
            }
        } catch(Exception ignored) { }
        return result;
    }
    private static void metric(JSONArray array,String name,String value,String basis) throws Exception {array.put(new JSONObject().put("name",name).put("value",value).put("basis",basis));}
    private static String number(JSONObject object,String key,String unit) {double value=object.optDouble(key,Double.NaN);return Double.isFinite(value)?format(value)+unit:"자료 없음";}
    private static String format(double value) {return value==Math.rint(value)?String.format(Locale.ROOT,"%.0f",value):String.format(Locale.ROOT,"%.1f",value);}
    private static String comparison(JSONObject a,JSONObject b,String key,String prefix) {
        double delta=a.optDouble(key,Double.NaN)-b.optDouble(key,Double.NaN);
        if(!Double.isFinite(delta)) return prefix.isEmpty()?"어제 비교 자료 없음":"체감 비교 자료 없음";
        if(Math.abs(delta)<.5) return prefix+"어제와 비슷해요";
        return prefix+"어제보다 "+Math.round(Math.abs(delta))+"° "+(delta<0?"낮아요":"높아요");
    }
    private static String condition(String value) {
        String s=value.toLowerCase(Locale.ROOT).replace(" ","");
        if(s.contains("소나기")||s.contains("shower"))return "shower";
        if((s.contains("비")&&s.contains("눈"))||s.contains("sleet"))return "wintryMix";
        if(s.contains("빗방울")||s.contains("drizzle"))return "drizzle";
        if(s.contains("비")||s.contains("rain"))return "rain";
        if(s.contains("눈날림"))return "snowFlurry";
        if(s.contains("눈")||s.contains("snow"))return "snow";
        if(s.contains("구름많음")||s.contains("partly"))return "partlyCloudy";
        if(s.contains("흐림")||s.contains("cloud")||s.contains("구름"))return "overcast";
        return s.contains("맑음")||s.contains("clear")?"clear":"unknown";
    }
    private static JSONObject get(String raw,String key) throws Exception {
        HttpURLConnection connection=(HttpURLConnection)new URL(raw).openConnection();
        try {
            connection.setConnectTimeout(5000);connection.setReadTimeout(10000);
            connection.setInstanceFollowRedirects(false);
            WeatherCareWidgetRefreshWorker.authorizeTestServer(connection,key);
            if(connection.getResponseCode()!=200)throw new java.io.IOException("weather unavailable");
            try(var input=connection.getInputStream()) {
                var output=new java.io.ByteArrayOutputStream();
                byte[] buffer=new byte[8192];int count;
                while((count=input.read(buffer))!=-1) {
                    if(output.size()+count>512*1024)throw new java.io.IOException("weather too large");
                    output.write(buffer,0,count);
                }
                return new JSONObject(output.toString(StandardCharsets.UTF_8.name()));
            }
        } finally {connection.disconnect();}
    }
}
