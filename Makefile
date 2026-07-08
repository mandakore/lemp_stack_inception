NAME	= inception

COMPOSE = docker compose -f srcs/docker-compose.yml

DATA	= /home/atashiro/data

all:
		mkdir -p $(DATA)/wordpress
		mkdir -p $(DATA)/mariadb
		$(COMPOSE) up -d --build

down:
		$(COMPOSE) down

clean:
		$(COMPOSE) down --rmi all

fclean:
		$(COMPOSE) down -v --rmi all
		sudo rm -rf $(DATA)
		docker system prune -af

re:		fclean all

.PHONY: all down clean fclean re
