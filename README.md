# n8n-aws

Desired state for one **n8n** instance on AWS EC2, backed by a colocated
self-hosted **Neon** storage tier whose layers and WAL live in an S3 bucket
this deployment owns.

Public name: **https://n8n-aws.bigconfig.online**.

This repository holds no source code. `colors.yml` is the deployment; the
behaviour comes from the SHA-pinned [`getcolors/n8n`](https://github.com/getcolors/n8n)
Package Skill, whose launcher is installed here as `./green`.

## What create owns

`./green create` builds every resource this deployment needs and `./green
delete` removes all of them again. Nothing is prepared by hand in the AWS
console.

| Resource | Owner | Lifecycle |
|---|---|---|
| OpenTofu state bucket `n8n-aws-state-251213589273-us-east-1` | `colors-compute` (`s3-bucket-mode: managed`) | created before the first state read, removed last, after compute is gone |
| Neon data bucket `n8n-aws-neon-251213589273-us-east-1` | the package's `n8n-storage` stage (`n8n-storage-managed: true`) | created after compute, destroyed after DNS and before compute |
| Backup bucket `n8n-aws-backup-251213589273-us-east-1` | the same stage | same |
| One IAM user, policy and access key per bucket | the same stage | minted with the buckets; each key reaches exactly one bucket |
| VPC, subnet, security group, EC2 instance, machine SSH keypair | `colors-compute` | the Compute Provider and SSH Keypair Standards |
| `n8n-aws` DNS record in `bigconfig.online` | the package's DNS stage | removed before the instance is destroyed |

The storage stage refuses to adopt a bucket that already exists. A bucket name
that answers anything but 404 fails the converge, so a leftover from a
previous profile has to be removed by hand first.

## Use

```sh
direnv allow               # once, after populating .envrc.private
./green build              # render .colors/n8n-aws/ — offline, no credentials
./green create --dry-run   # walk the workflow, skip every side effect
./green create             # converge
./green delete             # guarded; see below
```

## Credentials

In the gitignored `.envrc.private`:

| Variable | For |
|---|---|
| `COLORS_PAR_AWS_ACCESS_KEY_ID` / `_SECRET_ACCESS_KEY` | compute, the state bucket, the storage stage; mapped onto the AWS credential chain by `.envrc` |
| `COLORS_PAR_CLOUDFLARE_API_TOKEN` | the DNS record; Zone:Read and DNS:Edit on `bigconfig.online` |
| `COLORS_PAR_N8N_ENCRYPTION_KEY` | at least 32 characters; keep a copy off this machine |

No `COLORS_PAR_NEON_R2_*` and no `COLORS_PAR_N8N_BACKUP_R2_*`. The storage
stage mints a bucket-scoped key for the Neon bucket and another for the backup
bucket and hands them to Ansible in memory. Neither reaches `colors.yml`,
`.colors/`, or this file.

Never export `COLORS_PAR_PROFILE`.

## Server-generated secrets

The database role password, the n8n owner password and the task-runner token
are created once on the server and are not operator credentials:

```sh
ssh n8n-aws "sudo cat /etc/n8n/secrets/owner-password"       # the n8n login
ssh n8n-aws "sudo cat /etc/neon/secrets/neon_role_password"  # the database role
```

The SSH user on AWS is `ubuntu`, not `root`. Because `cloudflare-proxied:
true`, the public name resolves to Cloudflare's edge; SSH uses the origin
address held by the `~/.ssh/config` alias the package writes.

## Deleting

`compute-prevent-destroy: true` guards `delete` and is rendered into the
storage stage as `prevent_destroy` on both buckets. Lift it for exactly one run:

```sh
COLORS_PAR_COMPUTE_PREVENT_DESTROY=false ./green delete
```

Delete stops the application, removes the SSH alias, removes the DNS record,
destroys the two application buckets with their objects and IAM users,
destroys compute, and finally removes the state bucket. A second delete is a
no-op that reports the state bucket as already gone. Never edit the committed
flag.

## Recovery

Backups run every six hours to the backup bucket as a set: a logical dump, a
tar of the n8n data directory, and a manifest with checksums and one shared
timestamp. The interval is the RPO, because a rebuilt safekeeper does not
recover its offloaded WAL.

```sh
ssh n8n-aws "/opt/neon/n8n-restore.sh <stamp> --verify-only"   # checksums
ssh n8n-aws "/opt/neon/n8n-rehearsal.sh"                       # full restore drill
```

## Operational drills

```sh
ssh n8n-aws /opt/neon/n8n-smoke.sh                    # the acceptance gates
ssh n8n-aws /opt/neon/n8n-soak.sh                     # load, declared thresholds
ssh n8n-aws /opt/neon/n8n-prune-drill.sh              # retention, isolated
ssh n8n-aws /opt/neon/n8n-restart-drill.sh recreate   # full stack recreate
```
