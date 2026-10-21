# TAX1102 Sheet Check

Open the app: https://japsantosrtco.github.io/tax1102-sheet-check/

A single-file phone web app for the supplied A4 bubble sheet. All image reading and
scoring happen in a browser worker. No real or demo answer key is embedded or fetched.
The code uses the supplied G1 geometry and item-type mapping verbatim.
For phone performance, the illumination background is blurred at quarter resolution
with sigma 6.25, then resized to the full sheet before division (equivalent target
sigma 25). An upright orientation skips the unused second warp. The supplied photos
are checked against this implementation, rather than assuming bit-for-bit Python output.

## Use it

1. Open the HTTPS app in current Android Chrome or iPhone Safari.
2. Tap **Load answer key**, then scan/upload the professor's key QR or paste its text.
   Keys stay in memory unless **Remember on this phone** is checked. **Forget all keys**
   removes both remembered and session keys. Two versions can be loaded independently.
3. Start the camera and hold all four black corner squares in view. Two consecutive
   identical readings accept a sheet. Or use **Choose photo** for one clear photo.
4. Review the score, separate theory/problem counts and any flags. Faint marks retain
   the shaded reading and require the professor's decision. Double/blank items are wrong.
5. Turn on **Professor mode** BEFORE scanning to retain a local list and export CSV.
   The toggle has no authentication. Anyone using that browser can see its list.

Without a matching key the app still reads the sheet, shows the answers and stores
null scores. Scores are out of 70, with one point per correct answer. The interface
does not apply any separate weighted grading scheme.

## Private database setup

Until connected, scans are explicitly **waiting to save**, not backed up remotely.
Records wait in localStorage, with grayscale sheet JPEGs in IndexedDB. Keep this
browser's site data and the original papers until uploads finish. Clearing site data,
private browsing, browser eviction or changing phones can destroy unsent data.

1. Create a new Supabase project in your own account (free plan is sufficient to start).
2. Run the complete `setup.sql` once in its SQL editor. It creates the `scans` table,
   enables row-level security and creates the private `sheets` bucket. Use a dedicated
   project: pre-existing broad Storage policies could otherwise grant unwanted access.
3. Copy the project URL and PUBLIC publishable key (`sb_publishable_...`) or legacy anon
   key. Enter them in the app's **Settings**, then tap **Save connection**.
4. To give all students the same connection automatically, put ONLY those public values
   in `DEFAULT_DB` inside `index.html`, then republish. Settings entered on one phone
   apply only to that browser. No secret/service-role key belongs in the HTML.
5. Scan a sheet. Check both its row and its private JPEG in the Supabase dashboard.
   The result says **Saved** only after both uploads have succeeded.

Uploads use POST only: Storage insert (no upsert), then database insert with
`Prefer: return=minimal`. The app never queries stored rows or downloads stored images.
A stable `scan_id` is an addition to the original schema for safe retries after a
network interruption. A duplicate-key response confirms a prior insert of that ID.
Open the page again, scan another sheet, reconnect to the internet or tap **Retry
waiting scans** to retry. Retries preserve the original capture time and score snapshot.

The public client can submit fabricated records and scores; Professor mode is a local
convenience, not an identity check. Use retained papers/images and your key when resolving
disputes or finalizing grades. An anonymous insert endpoint also needs usage monitoring
if the URL is widely shared. The SQL prevents public record/image reads, edits and deletes.

Supabase references: [API keys](https://supabase.com/docs/guides/api/api-keys),
[row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security),
[Storage access control](https://supabase.com/docs/guides/storage/security/access-control).

## Verify access after setup

Use the public key in the Supabase API explorer or a private terminal session:

```sh
# Set SCANNER_URL and SCANNER_PUBLIC_KEY privately; do not use a secret key here.
curl "$SCANNER_URL/rest/v1/scans?select=id,student_no" \
  -H "apikey: $SCANNER_PUBLIC_KEY"
```

Expect `[]` even after the dashboard shows rows. With a legacy anon JWT also send
`Authorization: Bearer $SCANNER_PUBLIC_KEY`; a modern publishable key is not a JWT.
Confirm public requests cannot update/delete a row, list/read private Storage files,
or upload outside `sheets/TX1102MT2627/...`. The SQL does not install any read policy.

## Read the results as professor

Use the Supabase dashboard SQL editor. For section 03, latest scan per fully read
student number (change the section as needed):

```sql
select distinct on (student_no)
  created_at, student_no, section, version_code, score,
  theory_score, problem_score, answers, flags, image_path
from public.scans
where exam = 'TX1102MT2627' and section = '03'
  and student_no !~ '\?'
order by student_no, created_at desc, id desc;
```

Export the result as CSV. Review unreadable student numbers separately; never merge
all `?` values into one student. To distinguish receipt time from client capture time,
use the increasing database `id`; the browser supplies `created_at` and its clock can vary.

Codex can also read/export records through an authorized private administrative session:
for example, “all scans for section 03, latest scan per student number, as CSV.”
Use an owner-side secret only in that protected administrative environment, never in
this app, public code, a screenshot or a shared message. The database stores no answer key.

## Hosting and network behavior

Deploy **index.html** to GitHub Pages or Netlify Drop. No build server is needed.
For GitHub Pages, use a public repository, enable Pages from `main` and the root folder,
and open its HTTPS `github.io` URL. For Netlify Drop, drag a folder containing index.html
into Netlify's manual deploy screen. Camera use needs HTTPS (localhost is accepted for QA).

GitHub reference: [configure a Pages source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

The initial page and pinned OpenCV.js 4.11.0 / jsQR 1.4.0 libraries are downloaded.
After library loading, the app sends only scan-record and private-image POSTs to the
configured Supabase project. No analytics, handwriting OCR or external image processing.
Reopening completely offline is not guaranteed: there is no service worker in this
single-file build. An already loaded reader works offline and queues accepted scans.

## Validation limits

See the accompanying local validation report for executed checks. Simulated photos
cannot establish actual phone camera focus, two-second lock time, physical pen marks,
or production database permissions. These require a real printed sheet on the target
phones and a configured Supabase project. Retain these checks before classroom use.
