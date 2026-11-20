# Stark Group VMS starter — Flutter + Spring Boot + Neon

This is an **overlay for your already-created monorepo**, not a replacement for your Flutter-generated project. Merge its `backend/`, `frontend/lib/`, `scripts/`, and `netlify.toml` paths into the same locations in your Git repository. Back up your changes before overwriting files.

## Architecture / decisions

- Flutter Web on Netlify -> HTTPS REST/JSON -> Spring Boot 4.1.2 on Render -> PostgreSQL on Neon.
- Spring Security resource server verifies HMAC-SHA256 JWT access tokens. Expiry: two hours. Tokens are held in Flutter application memory; reload signs out.
- BCrypt password hashing, auth validation, CORS restricted to configured web origin, stateless API, no database credentials in Flutter.
- Every vehicle belongs to the authenticated user. A user receives HTTP 404 when attempting to read/edit/archive another user's vehicle.
- `DELETE /api/v1/vehicles/{id}` performs a soft delete. It sets `is_deleted=true` and updates `updated_at`.
- Active number plates are globally unique, backed by a partial PostgreSQL unique index. A plate can be reused after the previous vehicle has been archived.
- Number plate is an uppercase **English transliteration** of your requested sample: `DHAKA METRO - GHA - 12 - 3456`. The app validates the shape but **does not certify** official BRTA class/engine-category correctness. Broaden city and Bengali script support in a later version.
- Mock records are inserted into **PostgreSQL**, never fake front-end arrays, only when Spring profile `dev` is active and `VMS_DEMO_EMAIL`/`VMS_DEMO_PASSWORD` are set.

## Directory changes

```text
<your-monorepo>/
├── backend/
│   ├── pom.xml                  (replace your generated pom.xml)
│   ├── Dockerfile
│   ├── .dockerignore
│   └── src/main/java/com/vms/backend/...
│   └── src/main/resources/application.yml
│   └── src/main/resources/db/migration/V1__init.sql
├── frontend/
│   ├── lib/main.dart            (replace your generated file)
│   ├── lib/api.dart
│   ├── lib/screens.dart
│   └── pubspec.yaml             (keep generated file; add `http: ^1.3.0`)
├── scripts/
│   ├── build_flutter_web.sh
│   └── smoke_test.sh
└── netlify.toml
```

## Step 1: Merge and install dependencies

Merge the overlay into your existing repo. **Do not delete** `frontend/android`, `frontend/ios`, `frontend/web`, or generated project settings.

In `frontend/pubspec.yaml`, add under `dependencies:` at the same indentation as other packages:

```yaml
  http: ^1.3.0
```

```bash
cd frontend
flutter pub get
cd ../backend
./mvnw clean test       # generated wrapper if present, otherwise: mvn clean test
```

Requires a Java 21 JDK (backend), a currently supported Flutter SDK (frontend), and a network connection to fetch Maven/Pub dependencies.

## Step 2: Neon database

1. Create a Neon project and a PostgreSQL database.
2. Neon Console > **Connect** > choose **direct** connection (disable the pooler). This starter uses a maximum of five Hikari connections, and Flyway migrations work best over direct connections.
3. Copy the hostname, database, user, password into environment variables; **do not paste the full `postgresql://...` URL into Spring JDBC's `DB_HOST`**.
4. The JDBC URL uses `sslmode=verify-full` with Java's TLS trust store. Neon uses trusted TLS certificates. Your runtime must contain CA certificates.
5. On first Spring Boot start, Flyway runs `V1__init.sql` to create the `app_users`, `vehicles`, and index structures; Hibernate verifies the schema.

Use **separate Neon databases or branches for development and production**, especially if enabling demo seeding.

## Step 3: Environment variables

Place these in your local shell or IDE run configuration:

```bash
export DB_HOST='ep-...region.aws.neon.tech'
export DB_PORT=5432
export DB_NAME='neondb'
export DB_USER='neondb_owner'
export DB_PASSWORD='your-neon-password'
export JWT_SECRET_BASE64="$(openssl rand -base64 32)"
export ALLOWED_ORIGINS='http://localhost:3000'

# Optional mock data, on your *development* database only:
export SPRING_PROFILES_ACTIVE=dev
export VMS_DEMO_EMAIL='demo@example.com'
export VMS_DEMO_PASSWORD='choose-your-own-strong-demo-password'
```

**Do not run `openssl rand` separately each time you start the server while maintaining sessions.** Store a stable secret in a local, git-ignored `.env` or your IDE's secure run configuration. Rotation immediately invalidates existing JWTs. Do not commit the secret.

Run:

```bash
cd backend
./mvnw spring-boot:run
```

The API should answer: `http://localhost:8080/api/v1/health` -> `{"status":"UP"}`.

## Step 4: Flutter web

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8080
```

Open `http://localhost:3000`. With `dev` profile and demo vars, sign in using your configured email/password and see six database-backed demo vehicles. Or create your own account and add vehicles.

## REST contract

All vehicle routes require `Authorization: Bearer <token>`.

| Method | Path | Purpose | Success |
| --- | --- | --- | --- |
| GET | `/api/v1/health` | Liveness | 200 |
| POST | `/api/v1/auth/register` | New account + token | 201 |
| POST | `/api/v1/auth/login` | Obtain token | 200 |
| GET | `/api/v1/vehicles?page=0&size=10&search=...` | User's active vehicles, paginated | 200 |
| GET | `/api/v1/vehicles/{uuid}` | One owned, active vehicle | 200 |
| POST | `/api/v1/vehicles` | Register vehicle | 201 |
| PUT | `/api/v1/vehicles/{uuid}` | Replace vehicle fields | 200 |
| DELETE | `/api/v1/vehicles/{uuid}` | Soft delete only | 204 |

Register JSON:

```json
{"fullName":"Fleet Manager","email":"manager@example.com","password":"your-long-password"}
```

Vehicle create/update JSON:

```json
{
  "vehicleName": "Operations Jeep 01",
  "manufacturer": "Toyota",
  "model": "Land Cruiser",
  "color": "White",
  "seatCapacity": 7,
  "numberPlate": "DHAKA METRO - GHA - 12 - 3456",
  "engineCc": 2800,
  "vehicleType": "SUV",
  "fuelType": "DIESEL",
  "status": "AVAILABLE",
  "assignedDepot": "Dhaka Central Depot",
  "manufactureYear": 2023,
  "notes": "Office transport"
}
```

Available enums: `vehicleType` = SEDAN/SUV/MICROBUS/BUS/TRUCK/MOTORBIKE/VAN/OTHER; `fuelType` = PETROL/DIESEL/CNG/HYBRID/ELECTRIC/OTHER; `status` = AVAILABLE/ASSIGNED/MAINTENANCE/INACTIVE.

Errors: `400` invalid form, `401` missing/invalid credentials, `403` restricted access, `404` vehicle not found, `409` duplicate email/plate. Duplicate plate is enforced both in service logic and a PostgreSQL partial unique index.

## Step 5: Render backend (after local API tests pass)

- Dashboard > New > **Web Service**, link your existing GitHub monorepo.
- Runtime: **Docker**, root directory `backend`, Dockerfile `Dockerfile`.
- Add environment variables in Render dashboard: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET_BASE64`, `ALLOWED_ORIGINS`.
- `ALLOWED_ORIGINS=https://your-site.netlify.app` (add any custom domain comma-separated). Do not use a wildcard in production.
- Leave `SPRING_PROFILES_ACTIVE`, `VMS_DEMO_EMAIL`, and `VMS_DEMO_PASSWORD` **unset** in Render.
- Set health check path `/api/v1/health`.
- The application binds to `PORT` supplied by Render (fallback 8080), listening on `0.0.0.0`.

The Render URL is **public**. This is expected. Authentication + authorization protects application resources; obscuring URLs does not.

## Step 6: Netlify frontend (after Render URL is known)

- Dashboard > Add new project > Import Git repository. Select the **same monorepo**.
- `netlify.toml` specifies `base = frontend`, build via `scripts/build_flutter_web.sh`, and `publish = build/web`.
- Add Netlify environment variable `API_BASE_URL=https://your-render-service.onrender.com` (no trailing slash needed).
- Netlify fetches a Flutter SDK during the build if one is not installed. This makes builds slower; a CI pipeline caching Flutter is a worthwhile later optimization.
- Set `ALLOWED_ORIGINS` on Render to your exact final Netlify HTTPS site hostname and redeploy the backend.

Do not add database passwords or JWT secrets to Netlify environment variables; Netlify front-end build values are not secrets.

## Security verification before public release

- `GET /api/v1/vehicles` without bearer token must give `401`.
- A user cannot GET, PUT, or DELETE a vehicle owned by another user (expect `404`).
- Duplicate active plate must yield `409`, even across users. A soft-deleted vehicle must not appear in lists and must remain in PostgreSQL.
- Check Neon with `SELECT id, number_plate, is_deleted, updated_at FROM vehicles ORDER BY updated_at DESC;`.
- Store JWT secret and database password in Render secret environment configuration only.
- Use HTTPS for both Netlify and Render. Set explicit production CORS origins.
- Before broader public use, add login-rate-limiting, email verification, forgot-password flow, audit logs, token revocation/refresh, and integration tests for authorization and concurrent duplicate inserts. This is a starter, not a fully hardened enterprise identity platform.

## Automated quick smoke test (development only)

With backend already running, and `jq` installed:

```bash
bash scripts/smoke_test.sh
```

It checks health, anonymous access denial, registration, vehicle creation, duplicate rejection, soft deletion and post-delete visibility. It creates a throwaway test account in the connected database.

## Notes

- Demo records use illustrative registration plates, not BRTA-certified records.
- Dashboard shows a **global total of the signed-in user's active vehicles** and **per-page** assigned/available/maintenance counts, labeled accordingly.
- The `DELETE` endpoint is intentionally not a true database deletion.
- Browser refresh signs out because tokens are held only in application memory. This is intentional for the MVP security trade-off.
- The starter has not been compiled or integration-tested in this chat environment because Maven, Flutter, and network package downloads are unavailable here. Run the described commands locally and share compiler output if anything differs in your generated setup.
