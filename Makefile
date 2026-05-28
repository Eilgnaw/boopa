.PHONY: setup generate clean

setup:
	mise install && mise x -- tuist install && mise x -- tuist generate

generate:
	mise x -- tuist generate

clean:
	mise x -- tuist clean
