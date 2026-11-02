package com.codesoha.weathercare.wearbridge;

/** 휴대전화의 인증정보·좌표를 보내지 않는 버전 고정 Data Layer 계약. */
public final class WearContract {
    public static final String SNAPSHOT_PATH = "/weather-care/v1/snapshot";
    public static final String REQUEST_PATH = "/weather-care/v1/request";
    public static final String PAYLOAD_KEY = "payload";
    public static final int MAX_BYTES = 90 * 1024;
    private WearContract() { }
}
