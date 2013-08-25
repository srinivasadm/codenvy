/*
 * Copyright (C) 2013 Codenvy.
 */
package com.codenvy.analytics.metrics;

/** @author <a href="mailto:abazko@codenvy.com">Anatoliy Bazko</a> */
public class FactoryUrlTopSessions90DayMetric extends AbstractTopSessionsMetric {

    public FactoryUrlTopSessions90DayMetric() {
        super(MetricType.FACTORY_URL_TOP_SESSIONS_BY_90DAY, 90);
    }
}
