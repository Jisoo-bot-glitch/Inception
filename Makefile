COMPOSE = docker compose -f srcs/docker-compose.yml
DATA    = /home/jisobaek/data

all: up

up:
	mkdir -p $(DATA)/mariadb $(DATA)/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

re: down up

clean:
	$(COMPOSE) down --rmi all

fclean:
	$(COMPOSE) down --rmi all -v
	sudo rm -rf $(DATA)

.PHONY: all up down re clean fclean
