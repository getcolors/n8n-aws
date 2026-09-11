# CLAUDE.md

Guidance for agents working in this deployment. Read
`~/code/getcolors/CLAUDE.md` first.

## What this is

Desired state only. No source code. `colors.yml` is the single file to edit;
everything else is either generated (`.colors/`), secret (`.envrc.private`), or
an installed copy of the Package Skill launcher.

## Things specific to this deployment

- **Three S3 buckets are owned resources, like the SSH keypair.** The state
  bucket belongs to `colors-compute` through `s3-bucket-mode: managed`; the
  Neon and backup buckets belong to the package's `n8n-storage` stage through
  `n8n-storage-managed: true`. `create` makes them, `delete` removes them with
  their contents. Do not create any of them by hand: the storage stage fails
  when a bucket already exists.
- **`colors.yml` carries `neon-r2-*` keys that point at S3.** The package
  renders the `getcolors/neon` templates from a SHA pin rather than copying
  them, so it must speak that package's vocabulary. The endpoint
  `https://s3.us-east-1.amazonaws.com` is what makes them S3; the key names
  do not.
- **No operator bucket credentials.** The storage stage mints one scoped key
  per bucket from OpenTofu output and passes them to Ansible in the process
  environment as `COLORS_PAR_NEON_R2_*` and `COLORS_PAR_N8N_BACKUP_R2_*`. The
  R2 credential-sharing gate does not apply here.
- **AWS authenticates from the ambient chain.** `.envrc` maps the
  `COLORS_PAR_AWS_*` pair onto `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
- **`n8n-http-sources: cloudflare`** is a symbolic source the package resolves
  at converge time into the security group. It requires
  `cloudflare-proxied: true`; the validator refuses the other combination.
  AWS security groups are IPv4 only here, so the source lists carry no `::/0`.
- **The SSH user is `ubuntu`.** Reads of `/etc/n8n/secrets/` and
  `/etc/neon/secrets/` need `sudo`.

## Before any converge

```sh
./green build                                    # renders offline
./green create --dry-run                         # walks the workflow, no side effects
ansible-playbook --syntax-check -i inventory.json site.yml   # in .colors/n8n-aws/n8n-ansible
```

## Never

- Edit `.colors/`; it is generated.
- Edit `compute-prevent-destroy` in committed state.
- Export `COLORS_PAR_PROFILE`.
- Create or delete the three buckets outside the launcher.
