# Hints (progressive — try to only read as far as you need)

**Flag 1** — View page source on `/`.

**Flag 2** — `/guest-token` hands you a JWT. Decode the payload (middle
segment) — you don't need the signing secret to read it.

**Flag 3** — The login form builds its SQL query by pasting your input
straight in, and there's no legitimate admin credential anywhere to
find. What username makes the query always match?

**Flag 4** — The admin panel has a "preview a link" feature that fetches
URLs server-side, with no allowlist on the host. Something else lives
on this network, reachable by hostname.

**Flag 5** — The internal service's `/config` endpoint tells you
exactly how it's "protected" if you read its homepage first — base64,
then a very old-fashioned single-byte cipher, key included.

**Flag 6** — Once you have the real token, a second endpoint on that
same service accepts it and does something useful with it. Read a file
you haven't been given a path to yet.

**Flag 7** — What you just read wasn't only a flag.

**Flag 8** — Once you're on the third host, check what you can run as
root without a password.

**Flag 9** — Once you're root there, look for something that reads
like it was left for you specifically, not routine logging.

**Flag 10** — Count how many short, non-flag-shaped strings you've
picked up along this chain. There's a reason it's more than one.
