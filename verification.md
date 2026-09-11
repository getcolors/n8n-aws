# Verification

Live verification of `n8n-aws` on 2026-09-11, AWS account `251213589273`,
region `us-east-1`, availability zone `us-east-1a`, from the workstation at
`89.168.97.254`. Package `getcolors/n8n` at `be6a5ef` (green launcher stamped
by `91a483d`), installed with the Skills CLI; `skills-lock.json` records the
payload. Raw logs are under `evidence/`.

## First create

`./green create` returned 0 after 677 s (`evidence/live-create-1.txt`).
Stage durations: compute 133 s, storage 29 s, DNS 7 s, SSH config 1 s,
Ansible 502 s, acceptance 4 s. The acceptance step read the generated role
password as `ubuntu` through `sudo -n` and completed the tunnelled SQL round
trip with it, and was refused without it.

`evidence/storage-after-create.txt` records what create owns: the state
bucket tagged `colors:purpose=managed-backend` holding the compute, DNS and
storage state files and the `_colors/backend-owner.json` marker; the Neon
and backup buckets tagged `colors:owner=n8n-storage`; public access blocked
and AES256 on all three; IAM users `n8n-aws-storage-neon` and
`n8n-aws-storage-backup` with one active key each and a policy whose only
resources are their own bucket; one `t3.xlarge` with an encrypted 60 GiB gp3
root; a security group with 15 IPv4 Cloudflare ranges on 80 and 443 and one
address on 22.

## Gates

`evidence/smoke-after-create-1.txt`: all 18 host gates passed in 27 s,
among them the tenant attachment, 18 pageserver objects and a fresh
safekeeper segment after `pg_switch_wal()`, a workflow created through the
API and read back from Neon, 246 migrations, liveness and readiness, the
origin certificate, `N8N_WEBHOOK_URL`, the claimed owner, a Code node
executed on the external runner, sshd negatives, and gate R2 in `split`
mode: the backup credential is scoped away from live data.

`evidence/public-after-create.txt`: the record is a proxied A record; the
edge answers 200 on readiness and settings; a Let's Encrypt certificate was
issued behind the IPv4-only security group; ports 80 and 443 on the origin
time out from the workstation; port 22 answers.

`evidence/credential-isolation.txt`: from the host, the backup key lists
the backup bucket and is refused `s3:ListBucket` on the Neon bucket by IAM;
the Neon key is refused on the backup bucket the same way.

## Backups and drills

| Drill | Evidence | Result |
|---|---|---|
| backup set `20260911T065341Z` | `evidence/backup-1.txt` | uploaded in 15 s after a graceful n8n stop |
| restore `--verify-only` | `evidence/backup-verify-1.txt` | matches its manifest |
| soak, 300 s, declared mix | `evidence/soak-1.txt` | 2930 executions, 0 failed, SQL p95 120 ms, p99 153 ms, memory 12 %, disk 28 % |
| restore rehearsal | `evidence/rehearsal-1.txt` | 130 tables restored, login, workflow present, credential decrypted by execution, binary readable, 56 s |
| retention drill | `evidence/prune-drill-1.txt` | 528 executions pruned to the cap of 5, 151 s |
| restart drill, recreate | `evidence/restart-drill-1.txt` | stack returned healthy unattended, witness survived, Code node executes, 51 s |

The soak numbers are for `t3.xlarge` with gp3; the Vultr NVMe numbers in
the `n8n-single-node` Context Skill are not comparable.

## Second create

`./green create` a second time returned 0 after 304 s
(`evidence/live-create-2.txt`). The storage stage still applied: a read-only
`tofu plan` afterwards showed both SSE configurations updated in place on
every run (`evidence/storage-plan-after-create-2.txt`). S3 now creates
buckets with `BlockedEncryptionTypes: SSE-C` and `BucketKeyEnabled: false`,
and a rule that declares neither is removed and re-added by provider 6.31.0
each time. Package commit `e95536f` declares both; with the launcher
refreshed to `600b809` a third create returned 0 after 287 s
(`evidence/live-create-3.txt`) and the plan reads "No changes"
(`evidence/storage-plan-after-create-3.txt`).

## Delete

Without the override, `./green delete` stops at the guard with exit 2
(`evidence/delete-guard.txt`). With `COLORS_PAR_COMPUTE_PREVENT_DESTROY=false`
it returned 0 after 251 s (`evidence/live-delete-1.txt`) in the order load,
Ansible, SSH config, DNS, storage, infrastructure, backend finalize. A second
delete returned 0 after 4 s through the finalize-only path
(`evidence/live-delete-2.txt`).

`evidence/audit-after-delete.txt`: no `n8n-aws` bucket, no instance, no
keypair, no non-default security group, no volume, no IAM user beyond the
operator's, no DNS record, no local key, no SSH alias block. The three
`eu-west-1` buckets in the listing predate this deployment and belong to the
ONCE work.
