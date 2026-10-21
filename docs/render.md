# Render reference

The full story behind deploying to Render. The short version is in the [README](../README.md#deploy-to-render).

Unlike Railway, Fly.io, Dokploy and Coolify, Render gets a public HTTPS domain for free, so the office is reachable directly at `https://<name>.onrender.com` — no SSH tunnel for you or your team. That also means there's no SSH gate in front of it: `AGENT_OFFICE_PASSWORD` is the only thing keeping it private, so make it long and random, and treat the Render dashboard's own access controls as part of the office's security.

## Deploying

1. Push this repo to a GitHub repository Render can see (a fork of this one works fine).
2. On [Render's dashboard](https://dashboard.render.com), **New → Blueprint**, and point it at that repo. It reads [`render.yaml`](../render.yaml) at the root and proposes one web service, `agent-office`, on the **Starter** plan (the cheapest with a persistent disk — the free plan can't mount one).
3. Before the first deploy, open the service's **Environment** tab and set `AGENT_OFFICE_PASSWORD` (`openssl rand -base64 24` makes a good one). `render.yaml` leaves it blank on purpose: without an SSH session to read a generated password back from, making one up here would just lock you out, so [`deploy/render/start.sh`](../deploy/render/start.sh) refuses to start without it.
4. Deploy. The first start takes a few minutes: it builds [`deploy/render/Dockerfile`](../deploy/render/Dockerfile) (Node 22, git, the GitHub CLI, build tools) and installs Claude Code onto the disk.
5. Open `https://<name>.onrender.com` and sign in with the password from step 3.

Sign in to GitHub with `gh auth login` from a shell at any desk (**🐚**), and Claude from a worker's `/login` — same as any other install. Neither needs SSH, since both happen inside the office itself.

Redeploy by pushing to the branch Render watches (`autoDeploy: true` in `render.yaml`), or from **Manual Deploy** in the dashboard.

## What survives a restart

Render replaces the container on every restart and redeploy; the disk at `/data` stays:

| On the disk | What it holds |
| --- | --- |
| `/data/home/agent-office` | The office's own data: the password hash, accounts and invites, floors, chat, settings, arcade scores, each account's own Claude and GitHub sign-ins |
| `/data/home/workspace` | The projects, cloned as `<owner>/<repo>`, with the workers' worktrees |
| `/data/home/.local`, `.claude`, `.claude.json` | Claude Code itself, its sign-in, and the sessions workers resume |
| `/data/home/.config/gh`, `.gitconfig` | The GitHub CLI's sign-in and git's name and email |

The rest of the container (the office's code in `/opt/agent-office`, anything installed system-wide) comes fresh from the image each time. A restart or redeploy stops running workers; they come back at their desks when the office does.

## Inviting your team

There's no SSH, so skip step 1 of the README's [Add users](../README.md#add-users): everyone already reaches the same `https://<name>.onrender.com`. Just make them an account — **☰ → 🔑 Accounts** in the office, or `agent-office accounts invite ada` from a shell at a desk — and turn off the shared password once everyone has their own.

## Disk size and plan

`render.yaml` asks for a 10 GB disk on the **Starter** plan; both are adjustable from the dashboard (**Disks**, **Settings → Instance Type**) or by editing the blueprint and re-applying it. Cloned projects, their `node_modules`, and Claude Code's own install all live on the disk, so size it to however many floors and how much history you expect to keep.

## Security note

Every other way to run the office in this repo keeps it off the public internet: reachable only through an SSH tunnel (Railway, Fly.io, Dokploy, Coolify, [any server](self-hosting.md)) or a VPN (Tailscale's [`--tailscale`](self-hosting.md)). Render's free HTTPS domain is convenient exactly because it skips that — but it means there's no second factor if `AGENT_OFFICE_PASSWORD` leaks, the way an SSH key would be. Use a long, random password, and turn it off in **🔑 Accounts** once everyone has their own account (see [Add users](../README.md#add-users) in the README).
