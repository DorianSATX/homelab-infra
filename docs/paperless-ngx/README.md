# Paperless-ngx (CT 129)

http://192.0.2.1:8000, Paperless-ngx v3.0.5. Runs as an LXC on the Proxmox homelab, installed via the community-scripts.github.io installer (not Docker) -- Django app at `/opt/paperless/src`, venv at `/opt/paperless/.venv`, config at `/opt/paperless/paperless.conf`, consume folder at `/opt/paperless_data/consume`.

Not currently k3s-managed or provisioned by this repo's Terraform -- built directly via the community LXC script. Candidate for eventual IaC/k3s migration.

## Working setup
- Folder consumption is active -- scanned docs land in Paperless, get OCR'd, and archived automatically.
- Scheduled background tasks run hourly: "Train Classifier" and "Check Workflows".
- **Tags** (Attributes > Tags), "Any word" content matching:
  - Bills -- invoice, bill, statement, balance-due, amount-due
  - Receipts -- receipt, purchase, order-confirmation
  - Tax -- tax, irs, 1099, w2, w-2
  - Medical -- patient, diagnosis, prescription, clinic, doctor
  - Insurance -- insurance, policy, premium, claim
  - Warranty -- warranty, guarantee
  - Legal -- agreement, contract, legal
  - Personal -- manual only (no auto-match rule)
  - Needs Review -- manual/assigned by workflow (see below)
- **Document types** (Attributes > Document types), same "Any word" matching: Invoice (invoice), Receipt (receipt), Bank Statement (statement, account-summary), Contract (contract, agreement), Letter (manual only).
- **Storage path** "Auto-Archive by Date": `Archive/{{ created_year }}/{{ created_month }}/{{ title }}`
- **Workflow** "Auto-file everything" (enabled, sort order 1): trigger = Consumption Started (no filter), actions = assign tag "Needs Review" + assign storage path "Auto-Archive by Date". Guarantees every new document gets filed and flagged for review even if no keyword rule matches.
- Correspondents intentionally not pre-created -- add as real senders show up (Attributes > Correspondents).
- API Auth Token generated in My Profile, required for any script/assistant calling the REST API. Not stored here -- regenerate from My Profile if lost, or check Vaultwarden.

## Scanner: Fujitsu ScanSnap S1300i
USB-passed-through directly into this LXC (`lsusb` shows `04c5:128d Fujitsu, Ltd ScanSnap S1300i`) -- no Windows PC / ScanSnap Home involved. Uses Linux SANE with the `epjitsu` backend (natively supported for this model). `scanbd` watches for the physical button press and runs `scan-to-paperless.sh` (copy in this folder), which scans via `scanimage` (ADF Duplex, color, 300dpi) and converts pages to a PDF with `img2pdf`, dropped directly into `/opt/paperless_data/consume`.

**Manual scan trigger** (re-checks the consume folder, does not itself invoke the scanner):
```
cd /opt/paperless/src && /opt/paperless/.venv/bin/python manage.py document_consumer --oneshot
```

**Bug fixed 2026-09-08**: `scan-to-paperless.sh` originally addressed the scanner via `net:localhost:epjitsu:libusb:...` (SANE's network daemon, port 6566), but `saned.service` on this LXC is masked/disabled -- nothing was listening to service that connection, even though `scanimage -L` cosmetically listed the `net:localhost:...` device. `scanbd` correctly detected every button press and ran the script, but `scanimage` failed every time with `Error during device I/O`. Fixed by pointing the script at the scanner directly instead: `epjitsu:libusb:001:004` (the same address `scanbd` already uses to detect the button), via `sed -i "s/net:localhost:epjitsu/epjitsu/" /usr/local/bin/scan-to-paperless.sh`. Confirmed working.

Diagnostics if this breaks again: `lsusb` (device visible to the LXC?), `scanimage -L` (can SANE address it?), `systemctl status scanbd` (is the button daemon running?), `journalctl -u scanbd -n 30 --no-pager` (untruncated button-press + scan-attempt history).

Cosmetic non-issue: after an LXC reboot, `scanbd` sometimes logs `no devices, not starting any polling thread` once or twice before the USB device is fully enumerated -- self-recovers, no action needed.

## Not yet backed up here
- Full `/opt/paperless/paperless.conf` (only the consume-related lines have been captured so far)
- Tag/doc-type/workflow definitions as exported JSON (currently only exist as UI config in the running instance)

## Possible next steps
- Add real Correspondents as they come up.
- Consider enabling AI Settings (LLM suggestions) later -- suggestion-only, lower priority.
- Set up Mail accounts/rules under Mail if documents should be pulled from an email inbox.
- Switch some tags/doc types from "Any word" to "Automatic" (ML) matching once there's real usage history.
