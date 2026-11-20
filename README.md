# Glossa

Glossa is a Flutter heritage-language learning app backed by a FastAPI API and PostgreSQL database. The backend validates accounts, lesson answers, and lesson completion rewards.

## Requirements

- Flutter SDK for the platform you want to run
- Docker Engine and the Docker Compose plugin
- Git

## Get started

Clone the repository and enter the project directory:

```sh
git clone <repository-url>
cd glossa
```

Start the API and database from the project root:

```sh
docker compose up --build
```

Leave this terminal running. On first startup, Compose builds the API image, waits for PostgreSQL, applies database migrations, inserts the starter lesson content, and starts the API. The database is stored in a Docker volume named `glossa_pgdata` and remains available after containers stop.

In a second terminal, install Flutter packages and run the app:

```sh
flutter pub get
flutter run
```

The API endpoints are available at `http://localhost:8000`; interactive API documentation is at `http://localhost:8000/docs`. Check that the API is ready at `http://localhost:8000/health`, which should return `{"status":"ok"}`.

To stop the backend, press **Ctrl+C** in the Compose terminal. To start it again without rebuilding, use `docker compose up`.

## Choose the API address

The app's default API address depends on the Flutter target:

| Flutter target | Default API address |
| --- | --- |
| Linux, macOS, or Windows desktop | `http://127.0.0.1:8000` |
| Android emulator | `http://10.0.2.2:8000` |

For a physical phone, the phone and development computer must be on the same local network. Find the computer's local IP address (on Linux, run `hostname -I`), then launch Flutter with that address:

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
```

Replace `192.168.1.23` with the computer's actual Wi-Fi IP. Verify connectivity by opening `http://192.168.1.23:8000/health` in the phone's browser. If it cannot connect, check that the phone and computer share a network and that the computer's firewall allows incoming connections on port `8000`.

When launching from an IDE, pass the same value as a Dart define in the Flutter run configuration:

```text
API_BASE_URL=http://192.168.1.23:8000
```

For a deployed backend, set `API_BASE_URL` to its reachable API origin. Production deployments should use HTTPS.

## Lesson content and database

Starter lessons and exercises are defined in `backend/seed.py`. Each lesson and exercise has a stable ID; exercise options and matching pairs are stored as JSON. The seed script inserts records that are missing, but it does not overwrite existing records with the same ID. To update existing lesson content in a fresh or existing database, update the seed behavior/data as needed; to change table structure, create a database migration under `backend/migrations/versions/`.

You can inspect or edit the running PostgreSQL database with a GUI such as DBeaver or pgAdmin:

- Host: `localhost`
- Port: `5432`
- Database: `glossa`
- Username: `glossa`
- Password: `glossa`

The local credentials are for development only. Add a lesson before its exercises because each exercise references a lesson ID. If editing content through a database GUI, also update `backend/seed.py` so the change can be recreated from the repository.

To open the database in the terminal instead, run this from the project root:

```sh
docker compose exec db psql -U glossa -d glossa
```

Inside `psql`, `\dt` lists tables and `\q` exits.

## Accounts and data

Accounts use an email address and a password of at least eight characters. Access tokens are stored with the platform secure-storage plugin. The Family leaderboard currently includes all users because the app does not yet have family or group membership.

To remove the local database and all its saved account/progress data, run:

```sh
docker compose down -v
```

This permanently deletes the local PostgreSQL volume. Do not use this command if you need to keep the data.
