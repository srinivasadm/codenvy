/*
 *
 * CODENVY CONFIDENTIAL
 * ________________
 *
 * [2012] - [2014] Codenvy, S.A.
 * All Rights Reserved.
 * NOTICE: All information contained herein is, and remains
 * the property of Codenvy S.A. and its suppliers,
 * if any. The intellectual and technical concepts contained
 * herein are proprietary to Codenvy S.A.
 * and its suppliers and may be covered by U.S. and Foreign Patents,
 * patents in process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Codenvy S.A..
 */
package com.codenvy.analytics.metrics.sessions;

import com.codenvy.analytics.datamodel.LongValueData;
import com.codenvy.analytics.datamodel.ValueData;
import com.codenvy.analytics.metrics.MetricType;
import com.codenvy.analytics.metrics.ReadBasedMetric;
import com.mongodb.BasicDBObject;
import com.mongodb.DBObject;

import java.io.IOException;
import java.text.ParseException;
import java.util.Map;

/** @author Anatoliy Bazko */
public abstract class AbstractProductUsageCondition extends ReadBasedMetric {

    final private long    minTime;
    final private long    maxTime;
    final private boolean includeMinTime;
    final private boolean includeMaxTime;
    final private String  operator;
    final private long    minSessions;
    final private long    maxSessions;
    final private boolean includeMinSessions;
    final private boolean includeMaxSessions;

    public AbstractProductUsageCondition(MetricType metricType,
                                         long minTime,
                                         long maxTime,
                                         boolean includeMinTime,
                                         boolean includeMaxTime,
                                         String operator,
                                         long minSessions,
                                         long maxSessions,
                                         boolean includeMinSessions,
                                         boolean includeMaxSessions) {
        super(metricType);
        this.minTime = minTime;
        this.maxTime = maxTime;
        this.minSessions = minSessions;
        this.maxSessions = maxSessions;
        this.includeMinTime = includeMinTime;
        this.includeMaxTime = includeMaxTime;
        this.includeMinSessions = includeMinSessions;
        this.includeMaxSessions = includeMaxSessions;
        this.operator = operator;
    }

    @Override
    public String getStorageCollectionName() {
        return getStorageCollectionName(MetricType.PRODUCT_USAGE_SESSIONS_LIST);
    }

    @Override
    public String[] getTrackedFields() {
        return new String[]{VALUE};
    }

    @Override
    public DBObject[] getSpecificDBOperations(Map<String, String> clauses) {
        DBObject group = new BasicDBObject();
        group.put(ID, "$" + USER);
        group.put(TIME, new BasicDBObject("$sum", "$" + TIME));
        group.put(SESSIONS, new BasicDBObject("$sum", 1));

        DBObject sessionsRange = new BasicDBObject();
        sessionsRange.put(includeMinSessions ? "$gte" : "$gt", minSessions);
        sessionsRange.put(includeMaxSessions ? "$lte" : "$lt", maxSessions);

        DBObject timeRange = new BasicDBObject();
        timeRange.put(includeMinTime ? "$gte" : "$gt", minTime);
        timeRange.put(includeMaxTime ? "$lte" : "$lt", maxTime);

        DBObject match = new BasicDBObject();
        match.put(operator, new DBObject[]{new BasicDBObject(SESSIONS, sessionsRange),
                                           new BasicDBObject(TIME, timeRange)});

        DBObject count = new BasicDBObject();
        count.put(ID, null);
        count.put(VALUE, new BasicDBObject("$sum", 1));

        return new DBObject[]{new BasicDBObject("$group", group),
                              new BasicDBObject("$match", match),
                              new BasicDBObject("$group", count)};
    }

    @Override
    public DBObject getFilter(Map<String, String> clauses) throws ParseException, IOException {
        DBObject filter = super.getFilter(clauses);

        DBObject match = (DBObject)filter.get("$match");
        if (match.get(USER) == null) {
            match.put(USER, REGISTERED_USER);
        }

        return filter;
    }

    @Override
    public Class<? extends ValueData> getValueDataClass() {
        return LongValueData.class;
    }
}
