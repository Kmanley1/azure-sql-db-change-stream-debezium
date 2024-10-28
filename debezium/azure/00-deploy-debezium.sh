#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail


echo "deploying eventhubs namespace"
az eventhubs namespace create \
	--resource-group "rg-debezium" \
	--location "WestUS2" \
	--name "debezium2" \
	--enable-kafka=true

echo "deploying schema history event hub"
az eventhubs eventhub create \
    --resource-group "rg-debezium" \
    --namespace-name "debezium2" \
    --name "schemahistory" \
    --partition-count 1 \
    --cleanup-policy Delete \
    --retention-time-in-hours 168 \
    --output none

echo "gathering eventhubs connection string"
EVENTHUB_CONNECTION_STRING=`az eventhubs namespace authorization-rule keys list --resource-group "rg-debezium" --name RootManageSharedAccessKey --namespace-name "debezium2" --output tsv --query 'primaryConnectionString'`


echo "deploying debezium container"
az container create \
	--resource-group "rg-debezium" \
	--location "WestUS2" \
	--name "debezium2" \
	--image debezium/connect:${2.7} \
	--ports 8083 \
	--ip-address Public \
	--os-type Linux \
	--cpu 2 \
	--memory 4 \
	--environment-variables \
		BOOTSTRAP_SERVERS=${"debezium2"}.servicebus.windows.net:9093 \
		GROUP_ID=1 \
		CONFIG_STORAGE_TOPIC=debezium_configs \
		OFFSET_STORAGE_TOPIC=debezium_offsets \
		STATUS_STORAGE_TOPIC=debezium_statuses \
		CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE=false \
		CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE=true \
		CONNECT_REQUEST_TIMEOUT_MS=60000 \
		CONNECT_SECURITY_PROTOCOL=SASL_SSL \
		CONNECT_SASL_MECHANISM=PLAIN \
		CONNECT_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EVENTHUB_CONNECTION_STRING}\";" \
		CONNECT_PRODUCER_SECURITY_PROTOCOL=SASL_SSL \
		CONNECT_PRODUCER_SASL_MECHANISM=PLAIN \
		CONNECT_PRODUCER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EVENTHUB_CONNECTION_STRING}\";" \
		CONNECT_CONSUMER_SECURITY_PROTOCOL=SASL_SSL \
		CONNECT_CONSUMER_SASL_MECHANISM=PLAIN \
		CONNECT_CONSUMER_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"${EVENTHUB_CONNECTION_STRING}\";"
 
echo "eventhub connection string"
echo $EVENTHUB_CONNECTION_STRING

Endpoint=sb://debezium2.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=frtw4l/mR4BHLtUQ7JElDGT15g4Uxhsyo+AEhHoS+V8=