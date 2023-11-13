# DOCKERFILE
FROM php:8.2-apache
COPY project /var/www/html

RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

EXPOSE 80

# Commande pour lancer le serveur Apache
CMD ["apache2-foreground"]