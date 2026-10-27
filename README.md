# LinkForge

LinkForge is a small URL shortener built to demonstrate a three-tier
application and its cloud infrastructure on Google Cloud.

## Architecture

- **Web:** static HTML, CSS and JavaScript served by nginx.
- **API:** FastAPI service for creating links, listing them and redirecting
  short codes.
- **Data:** Firestore stores link targets and click counts.
- **Platform:** Terraform modules for GKE, networking, Artifact Registry,
  Firestore and keyless workload identity.
- **Delivery:** GitHub Actions workflows are included for infrastructure and
  application CI/CD using Workload Identity Federation.

The browser talks to the API through the same origin; only the API accesses
Firestore. In GKE, the intended identity flow avoids long-lived service
account keys.

## Try it locally

The local stack uses the Firestore emulator and does not create GCP resources:

```bash
docker compose -f app/docker-compose.yml up --build
```

Open [http://localhost:8080](http://localhost:8080). Create a short link, open
it, and check that its click count increments. The API docs are available at
[http://localhost:8000/api/docs](http://localhost:8000/api/docs).

Stop the containers with `Ctrl-C`, then:

```bash
docker compose -f app/docker-compose.yml down
```

Run the API unit tests separately:

```bash
cd app/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q
```

## Infrastructure status

The Terraform root stack in `GCP/linkforge` currently represents the Chapter 03
foundation: project APIs, VPC networking, node identity, Artifact Registry and
Firestore. The GKE and workload-identity modules are present, but are not
currently wired into that root stack. The tutorial's later deployment chapters
describe the intended end-to-end configuration and should be reconciled with
the current stack before using those steps.

Provisioning GCP resources can incur charges. Review the [cost and teardown
guide](docs/gcp-3tier-tutorial/12-cost-control-and-teardown.md) before applying
Terraform or deploying an Ingress.

## Project layout

```text
GCP/
  linkforge/       Terraform root stack
  modules/         reusable GCP infrastructure modules
app/
  api/             FastAPI service and tests
  web/             static frontend and nginx configuration
k8s/               Kubernetes manifests
scripts/           build, deploy and environment helpers
docs/
  gcp-3tier-tutorial/  step-by-step architecture and deployment guide
.github/workflows/    GCP infrastructure and app workflows
```

## Documentation

Start with the [tutorial overview](docs/gcp-3tier-tutorial/00-overview.md),
then follow the [chapter index](docs/gcp-3tier-tutorial/README.md).
