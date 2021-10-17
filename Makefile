
bootstrap-env:
	@cp Bootstrap/dewPoint-env-example .dewPoint-env
	
bootstrap-topics:
	@cp Bootstrap/topics-example .topics

build:
	@swift build
	
run:
	@swift run dewPoint-controller
