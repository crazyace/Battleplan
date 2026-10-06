# Downloaded data snapshot

All downloaded JSON from the 2026-10-05 collection is retained byte-for-byte in
`full-snapshot.zip`, together with the collection manifests. `manifest.json`
records every member's length and SHA-256 and the archive SHA-256. Frontend
JavaScript/HTML and reproducible normalized SQLite/JSON copies are not included.

Sources: https://foreverdb.net/data/ and https://wowforevertalents.net/.
The raw records and collection manifests retain source URLs, build identifiers,
credits and licensing declarations. Older talent snapshots remain separate;
this import does not promote them into current builds or verified game facts.

The quest and vendor datasets declare derivation from CMaNGOS Classic DB
(https://github.com/cmangos/classic-db), GPL-3.0. Those records and the generated
acquisition catalog retain GPL-3.0 licensing; see `GPL-3.0.txt`. The repository's
MIT notice does not override upstream terms for imported data. Original raw JSON
and the generator are included as the preferred inputs for regenerating the
catalog. Other client-derived records retain their recorded provenance; absence
of a licensing declaration is not represented as an MIT grant.

`Battleplan/Data/FullGearCatalog.lua` is provisional data, not confirmed source
access. `catalog-report.json` explains which records the current model excludes.
The archive is developer reference material and is not loaded by the WoW client.

Regenerate and verify from the repository root:

```
python tools/import_full_data.py
python tools/import_full_data.py --check
```

To replace the collection, supply `--collection-dir PATH` to the importer. Keep
this notice and upstream license information with redistributed data.
