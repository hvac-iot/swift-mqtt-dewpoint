
bootstrap-env:
	@cp Bootstrap/dewPoint-env-example .dewPoint-env

build:
	@swift build
	
run:
	@swift run dewPoint-controller
