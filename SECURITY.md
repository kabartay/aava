# Security

Aava is an offline game. It has no server, no account and no network beyond
devices on the same local Wi-Fi, so the ways it can go wrong are narrow: the
local session, the microphone, and the files it writes on the device.

If you find something — a way to reach a session from outside the local network,
a way to start the microphone without the button being held, a way to read or
write another application's data — please write to
mukharbek.organokov@gmail.com rather than opening a public issue, and give me a
few days to answer before publishing.

There is no bounty. This is a game made for two brothers and given away; what I
can offer is that a real report gets taken seriously and credited.

## What is already guaranteed by the build

Some of the above is enforced by the check suite rather than by intention, and a
change that broke it would fail CI:

- the voice code cannot touch the filesystem, so nothing spoken is ever recorded
- the microphone is started in exactly one place, which is the talk button
- talking can be switched off, and then the microphone cannot start at all

See [docs/PRIVACY.md](docs/PRIVACY.md) for what the game stores and sends.
