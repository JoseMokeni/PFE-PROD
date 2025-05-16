# Le Coursier Production

## Prerequisites
1. Docker with Docker Compose installed
2. Required services running (See PFE_SERVICES repository):
    - PostgreSQL
    - Redis
    - Soketi
    - MailHog (for email testing)
    - Traefik (reverse proxy with Let's Encrypt)
3. Environment variables set in `.env` file (see `.env.example` for reference)
4. Stripe account created (for payment processing): Create alse the subscription plans in the Stripe dashboard and set the stripe environment variables in the `.env` file.
5. Firebase account created (for push notifications): Create a Firebase project and set the Firebase environment variables in the `.env` file.
6. Firebase service account added to the project: Download the service account JSON file from Firebase and save the file in the docker/firebase directory with the name `service-account.json`.

## Getting Started
1. Clone the repository
2. Navigate to the project directory
3. Copy the `.env.example` file to `.env` and update the environment variables as needed
4. Run the following command to start the services:
```bash
docker-compose up -d
```
5. Run the following command to install the dependencies:
```bash
docker-compose exec app composer install
```
6. Change the permissions of .env file:
```bash
docker-compose exec app chmod 644 .env
```
7. Run the following command to generate the application key:
```bash
docker-compose exec app php artisan key:generate
```
8. Run the following command to run the migrations:
```bash
docker-compose exec app php artisan migrate
```