
bootstrap-env:
	@cp Bootstrap/dewPoint-env-example .dewPoint-env

bootstrap-topics:
	@cp Bootstrap/topics-example .topics

bootstrap: bootstrap-env bootstrap-topics

build:
	@swift build

clean:
	rm -rf .build

run:
	@swift run dewPoint-controller

start-mosquitto:
	@docker-compose start mosquitto

stop-mosquitto:
	@docker-compose rm -f mosquitto || true

test-docker:
	@docker-compose run -i test
	@docker-compose kill mosquitto-test
	@docker-compose rm -f
