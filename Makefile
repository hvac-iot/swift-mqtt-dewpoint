
bootstrap-env:
	@cp Bootstrap/dewPoint-env-example .dewPoint-env
	
bootstrap-topics:
	@cp Bootstrap/topics-example .topics

build:
	@swift build
	
run:
	@swift run dewPoint-controller
	
start-mosquitto:
	@docker run \
		--name mosquitto \
		-d \
		-p 1883:1883 \
		-v $(PWD)/mosquitto/config:/mosquitto/config \
		eclipse-mosquitto

stop-mosquitto:
	@docker rm -f mosquitto || true
