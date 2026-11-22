# Actual ClamAV local validation

Executed 2026-11-22 against PR #29's unchanged `scanner.mjs`. Engine: **ClamAV 1.4.7**, daily database **28191**, signed build time **2026-11-22 06:27 UTC**. `sigtool --info` reported Verification OK; freshclam downloaded and load-tested daily/main/bytecode databases (28191/63/339). See [recorded JSON](clamav-results.json) for timestamps, timings and exact observations.

Official `clamav/clamav:stable` pulls failed twice with Docker registry CDN EOF errors. The fallback used the already cached Debian-based Python image and Debian packages to obtain updater/runtime dependencies. Debian supplied ClamAV 1.4.6, so the actual scan executable was replaced by the official 1.4.7 package extracted under `/opt/clamav147`. Its GitHub release SHA-256 matched `3bbb8ac72e9f9238d51ec6d52d8c34ab78967061ce6d15908fcbe4c4fb2bea3a`. This verifies the release digest; detached publisher GPG verification was not performed. The library path must point to the same extracted release; using Debian's older libclamav correctly failed the functionality-level check. Production image provenance needs its own signed-image review.

## Observed results

| Case | Result |
|---|---|
| Clean UTF-8 synthetic text, valid blank PDF, PCM WAV silence | CLEAN with real engine version receipt; approximately 5–6 seconds each on the local fixture host |
| Full standard harmless EICAR string | INFECTED by actual engine, not substring mock |
| Unsupported MIME, malformed magic, literal JavaScript/encryption PDF markers | Quarantined by existing format policy before engine; not claimed as parser/engine detections |
| Over 5 MiB adapter payload | ERROR before engine |
| Structurally invalid PDF and WAV with matching magic | **CLEAN — adverse finding S01**, no assertion reclassifies these as safe |
| Missing engine / stale signature mtime | ERROR; no admission |
| Actual clamscan killed at injected 1ms scan deadline | ERROR |
| Deliberately hung process using unchanged production execution options | ERROR after **45,011 ms**; version query still ran actual engine. Fault injection uses sleep, not a claim that a natural engine hang occurred |
| Real engine 6 MiB file limit on 7 MiB synthetic file, alert-exceeds-max | Exit 1, quarantinable detection |
| Auth + Storage + DB worker integration | PENDING read denied; clean -> CLEAN/read allowed; EICAR -> INFECTED/read denied; hash mismatch -> ERROR/read denied |

Runtime container: network `none`, read-only filesystem, repository read-only mount, no credentials, all capabilities dropped, no-new-privileges, 4 GiB memory, 2 CPUs, 64 PIDs, 256 MiB noexec/nosuid tmpfs. Cgroup readings are in the JSON. These prove configured bounds and observed file/timeout enforcement, not an exhaustive decompression-bomb/OOM load test. The scanner process runs as container root with dropped capabilities in this local harness; a production image must additionally use a dedicated non-root UID and be retested.

The worker integration runs `scanOne` on the host using local-only credentials and invokes the same adapter inside the network-disabled container. Only synthetic bytes cross stdin; the container receives no Supabase keys. It is not a deployed worker or proof of hosted networking. It handles an existing pending local backlog with a maximum of 25 claims. The test leaves synthetic fixtures for the guarded Reviewer Portal reset to remove.

## Reproduction (local only)

From repository root, with Docker, installed project dependencies and isolated Supabase already running:

```powershell
gh release download clamav-1.4.7 --repo Cisco-Talos/clamav --pattern clamav-1.4.7.linux.x86_64.deb --dir .studio-local
docker build --file tests/studio/Dockerfile.clamav --tag tafsiri-clamav-preflight:repro .studio-local
$repo = (Get-Location).Path
docker run -d --name tafsiri-clamav-runtime-001 --network none --read-only --tmpfs /tmp:rw,noexec,nosuid,size=256m --memory 4g --cpus 2 --pids-limit 64 --cap-drop ALL --security-opt no-new-privileges --mount "type=bind,source=$repo,target=/work,readonly" tafsiri-clamav-preflight:repro
docker exec tafsiri-clamav-runtime-001 node /work/tests/studio/clamav_preflight.mjs
node tests/studio/clamav_database.mjs
docker exec tafsiri-clamav-runtime-001 cat /tmp/clamav-results.json
```

Do not remove an already existing container with this name until its ownership is verified. Package download can be skipped if the exact file is present; the Dockerfile checks its digest. Freshclam is allowed network access only while building; do not bypass a failed download, invalid signature, stale database or engine failure. The Debian dependency packages/signature feeds can advance, so record the resulting versions/digest on every reproduction; the official engine/base image pins do not make the entire build bit-for-bit reproducible. Never replace the recorded JSON with a later run without recording the new date and commit.

The checked-in build recipe was built locally successfully. The original validated runtime image was `sha256:805fb11a655f8c2fa5a057886179f8c5ef41cb403d8478611ca7ad2e29af9045`, assembled with the equivalent manual package/extraction sequence. The engine must report 1.4.7 using the extracted libraries. A repeat build may differ because package indexes and signatures refresh.

After evidence capture, remove only the named disposable runtime/build containers and test images created by this task. Retain metadata results; expire ignored synthetic dumps/binaries under the approved local artifact policy. No broad Docker prune or existing Supabase cleanup is part of this procedure.

## Limits and required follow-up

No authentic documents, live malware, real speech or participant data were used. Valid WebM, obfuscated/indirect PDF actions, encrypted real PDF corpus, archive bombs and sustained concurrent load are not covered by this run. Literal policy-marker tests must not be presented as real encrypted-document parsing. Freshness is currently mtime-based; signing validation at download is useful but does not repair that runtime check. S01/S02 remain staging blockers under the requested file policy. Add reviewed structural parsers and signed-age checks in a separately authorized implementation, then rerun this matrix and extend it; do not change the expected observations to hide the finding.

References: [official Docker guidance](https://docs.clamav.net/manual/Installing/Docker.html), [ClamAV 1.4.7 release](https://github.com/Cisco-Talos/clamav/releases/tag/clamav-1.4.7), [official downloads](https://www.clamav.net/downloads). ClamAV recommends at least 3 GiB and preferably 4 GiB for its container workload; the proposed worker host reserves additional OS headroom.
