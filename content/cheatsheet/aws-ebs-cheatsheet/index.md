---
title: "AWS EBS Cheatsheet"
date: 2026-11-01T10:30:00+02:00
draft: false
description: "AWS CLI reference for Amazon EBS: volume types and limits (gp3 up to 80,000 IOPS), quick facts, create, copy, attach, resize and status-check volumes, snapshots (copy, share, multi-volume, DLM, lock, archive, Recycle Bin), encryption, Multi-Attach, initialization and fast snapshot restore, instance limits, RAID 0, read-ahead, torn write prevention, CloudWatch metrics and IMDSv2 self-provisioning. Commands checked against the AWS CLI 2.39.3 API model."
tags: ["aws", "ebs", "cli"]
categories: ["Cheatsheet"]
---

Amazon Elastic Block Store (EBS) provides block storage volumes for EC2 instances: SSD and HDD volume types,
point-in-time snapshots stored in S3, and online changes to size, type and performance. Every `aws` command
below passes the parameter and `--query` checks of AWS CLI 2.39.3, and the limits come from its API model
and the EBS User Guide (November 2026).

[![Where EBS data lives: a volume belongs to one Availability Zone and attaches only to instances there, copy-volumes copies it in the same AZ; create-snapshot stores a Region-wide snapshot in S3 that create-volume restores in any AZ, fully initialized with fast snapshot restore or an initialization rate; snapshots move to the archive tier and back, go to the Recycle Bin when deleted under a rule, are copied to other Regions and shared with other accounts](ebs-overview.svg)](ebs-overview.svg "Open the diagram full size")

## EBS Volume Types

| Type | Name | Use Case | Max IOPS | Max Throughput | Size | Durability | Multi-Attach |
|------|------|----------|----------|----------------|------|------------|--------------|
| `gp3` | General Purpose SSD | Most workloads (default) | 80,000 | 2,000 MiB/s | 1 GiB–64 TiB | 99.8–99.9% | No |
| `gp2` | General Purpose SSD | Legacy default | 16,000 (burst to 3,000 below 1 TiB) | 250 MiB/s | 1 GiB–16 TiB | 99.8–99.9% | No |
| `io2` (Block Express) | Provisioned IOPS SSD | Databases, latency-sensitive | 256,000 | 4,000 MiB/s | 4 GiB–64 TiB | 99.999% | Yes |
| `io1` | Provisioned IOPS SSD | Legacy provisioned IOPS | 64,000 | 1,000 MiB/s | 4 GiB–16 TiB | 99.8–99.9% | Yes |
| `st1` | Throughput Optimized HDD | Big data, log processing | 500 | 500 MiB/s | 125 GiB–16 TiB | 99.8–99.9% | No |
| `sc1` | Cold HDD | Infrequent access | 250 | 250 MiB/s | 125 GiB–16 TiB | 99.8–99.9% | No |

> `gp3` is the recommended default. It's about 20% cheaper per GiB than `gp2` and lets you set IOPS and throughput separately from size.
> Since April 30, 2025 every `io2` volume is an io2 Block Express volume; there is no separate type. The limits above come from the
> AWS CLI 2.39.3 `create-volume` help (gp3 up to 80,000 IOPS, 2,000 MiB/s and 64 TiB; on Outposts gp3 stays at 16,000 IOPS, 1,000 MiB/s and 16 TiB).

### Which Volume Type?

| If you need | Use |
|-------------|-----|
| Boot volumes, most apps and databases, dev/test | `gp3` (start at 3,000 IOPS / 125 MiB/s, raise as needed) |
| More than 80,000 IOPS or 2,000 MiB/s on one volume, sub-millisecond latency, 99.999% durability | `io2` |
| One volume shared by several instances (Multi-Attach) | `io2` (or `io1`) |
| Large sequential reads and writes: logs, Kafka, Hadoop/Spark, data warehouses | `st1` |
| Cold data scanned a few times a day, lowest cost per GiB | `sc1` |
| An existing `gp2` or `io1` volume | Move it to `gp3` / `io2` with `modify-volume`, online |

HDD types (`st1`, `sc1`) can't be boot volumes. Small random I/O belongs on SSD.

## Quick Facts

- **Scope**: a volume lives in one AZ and attaches only to instances in that AZ. Snapshots live in one Region; copy them to use them elsewhere.
- **Persistence**: data survives stop/start. On terminate, volumes with `DeleteOnTermination=true` (the root volume by default) are deleted.
- **Detach**: unmount first on a running instance. A root volume can only be detached after the instance is stopped.
- **New vs restored volumes**: empty volumes give full performance at once; volumes created from a snapshot are slow on first read of each block until initialized.
- **Snapshots**: stored in S3 (not visible as buckets), incremental, crash-consistent. Deleting one removes only the blocks no other snapshot needs.
- **Encryption** (KMS) covers data at rest, data moving between the instance and the volume, snapshots, and volumes made from them, with minimal effect on latency.
- **EBS-optimized**: current-generation instance types are EBS-optimized by default at no extra cost, so EBS traffic has its own bandwidth.
- **Elastic Volumes**: grow size, change type and adjust IOPS/throughput online. Shrinking is not possible.
- **Billing**: per provisioned GiB-month, detached or not (plus gp3 IOPS above 3,000 and throughput above 125 MiB/s, and io1/io2 IOPS). Snapshots bill for stored data; archive tier, FSR and initialization rate are extra.
- **Backups**: DLM for snapshot/AMI schedules, AWS Backup for cross-service plans, Recycle Bin against accidental deletes, snapshot lock against any delete.
- **Quotas**: EBS limits are per Region and mostly storage-based (TiB per volume type) rather than volume counts; list them with
  `aws service-quotas list-service-quotas --service-code ebs --query "Quotas[].[QuotaName,Value]" --output table`.

## Volume Management

### Create a Volume

```sh
# Create a gp3 volume
aws ec2 create-volume \
  --volume-type gp3 \
  --size 100 \
  --availability-zone us-east-1a \
  --iops 3000 \
  --throughput 125 \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=data-vol}]'

# Create an io2 volume
aws ec2 create-volume \
  --volume-type io2 \
  --size 500 \
  --iops 10000 \
  --availability-zone us-east-1a

# Create from a snapshot
aws ec2 create-volume \
  --snapshot-id snap-0abc123 \
  --volume-type gp3 \
  --availability-zone us-east-1a
```

### List Volumes

```sh
# List all volumes
aws ec2 describe-volumes --output table

# List with key details
aws ec2 describe-volumes \
  --query "Volumes[].{ID:VolumeId, Size:Size, Type:VolumeType, State:State, AZ:AvailabilityZone, Attached:Attachments[0].InstanceId}" \
  --output table

# Find unattached volumes (still billed while detached)
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query "Volumes[].{ID:VolumeId, Size:Size, Type:VolumeType, Created:CreateTime}" \
  --output table

# Find volumes by tag
aws ec2 describe-volumes \
  --filters "Name=tag:Name,Values=data-vol" \
  --output table

# Find volumes attached to a specific instance
aws ec2 describe-volumes \
  --filters "Name=attachment.instance-id,Values=i-0abc123" \
  --query "Volumes[].{ID:VolumeId, Device:Attachments[0].Device, Size:Size}" \
  --output table
```

### Attach a Volume

```sh
# Attach to an instance
aws ec2 attach-volume \
  --volume-id vol-0abc123 \
  --instance-id i-0abc123 \
  --device /dev/xvdf

# Wait for attachment
aws ec2 wait volume-in-use --volume-ids vol-0abc123
```

### Detach a Volume

```sh
# Graceful detach
aws ec2 detach-volume --volume-id vol-0abc123

# Force detach (if instance is unresponsive)
aws ec2 detach-volume --volume-id vol-0abc123 --force

# Wait for detachment
aws ec2 wait volume-available --volume-ids vol-0abc123
```

### Delete a Volume

```sh
# Delete a single volume
aws ec2 delete-volume --volume-id vol-0abc123

# Delete all unattached volumes (careful!)
aws ec2 describe-volumes --filters "Name=status,Values=available" \
  --query "Volumes[].VolumeId" --output text | \
  xargs -n1 aws ec2 delete-volume --volume-id
```

### Copy a Volume (Same AZ)

```sh
# Crash-consistent copy of a volume in the same AZ, without a snapshot; type, size and performance can change
aws ec2 copy-volumes \
  --source-volume-id vol-0abc123 \
  --volume-type gp3 \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=data-vol-copy}]'
```

### Volume Status Checks

```sh
# Status: ok | warning | impaired | insufficient-data
aws ec2 describe-volume-status --volume-ids vol-0abc123 \
  --query "VolumeStatuses[].{ID:VolumeId, Status:VolumeStatus.Status, Events:Events[].EventType}" \
  --output table

# All volumes that are not ok
aws ec2 describe-volume-status \
  --filters "Name=volume-status.status,Values=impaired,warning" \
  --output table

# After an impaired volume (possible inconsistency) has I/O disabled: check it, then re-enable I/O
aws ec2 enable-volume-io --volume-id vol-0abc123

# Or let EBS re-enable I/O automatically for this volume
aws ec2 modify-volume-attribute --volume-id vol-0abc123 --auto-enable-io
```

## Modify a Volume (Online Resize)

EBS volumes can be resized, change type, or adjust IOPS/throughput without downtime:

[![modify-volume goes through modifying, optimizing and completed; the new size is usable once optimizing starts, so lsblk, growpart and xfs_growfs or resize2fs can run then; the next change is allowed after completed, at most four per rolling 24 hours, and a fifth fails with an error that says when the next one is allowed](ebs-modify-volume.svg)](ebs-modify-volume.svg "Open the diagram full size")

```sh
# Increase size
aws ec2 modify-volume --volume-id vol-0abc123 --size 200

# Change type (gp2 → gp3)
aws ec2 modify-volume --volume-id vol-0abc123 --volume-type gp3

# Adjust IOPS and throughput (gp3)
aws ec2 modify-volume --volume-id vol-0abc123 \
  --volume-type gp3 \
  --iops 6000 \
  --throughput 500

# Check modification progress
aws ec2 describe-volumes-modifications --volume-ids vol-0abc123 \
  --query "VolumesModifications[0].{State:ModificationState, Progress:Progress, Original:OriginalSize, Target:TargetSize}" \
  --output table
```

After resizing, grow the filesystem inside the instance:

```sh
# XFS
sudo xfs_growfs /mount-point

# ext4
sudo resize2fs /dev/xvdf

# If partition-based, grow the partition first
sudo growpart /dev/xvdf 1
sudo resize2fs /dev/xvdf1
```

> Each modification must reach `completed` before you start the next one, and a volume can be modified up to 4 times in a rolling 24-hour period. Size increases take effect once the state is `optimizing` (usually seconds); the rest completes in the background. You can't shrink a volume.

## Snapshots

[![Three incremental snapshots: Snap 1 stores blocks A, B, C and D, Snap 2 stores only the changed B′, Snap 3 stores D′ and the new E and refers to the rest; deleting Snap 1 frees only B and D because A and C are still used, a volume restored from Snap 3 is complete (A B′ C D′ E), and archiving Snap 3 keeps a full copy of all five blocks](ebs-incremental-snapshots.svg)](ebs-incremental-snapshots.svg "Open the diagram full size")

### Create a Snapshot

```sh
# Snapshot a volume
aws ec2 create-snapshot \
  --volume-id vol-0abc123 \
  --description "Backup 2024-01-15" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=daily-backup}]'

# Snapshot a running instance with a frozen filesystem (consistent, not just crash-consistent)
# Best practice: flush filesystem first
ssh ec2-user@instance "sudo sync && sudo fsfreeze -f /data"
aws ec2 create-snapshot --volume-id vol-0abc123 --description "Consistent backup"
ssh ec2-user@instance "sudo fsfreeze -u /data"
```

### List Snapshots

```sh
# List your snapshots
aws ec2 describe-snapshots --owner-ids self \
  --query "Snapshots[].{ID:SnapshotId, Volume:VolumeId, Size:VolumeSize, State:State, Date:StartTime}" \
  --output table

# Find snapshots for a specific volume
aws ec2 describe-snapshots --owner-ids self \
  --filters "Name=volume-id,Values=vol-0abc123" \
  --output table

# Find snapshots older than 30 days (GNU date; on macOS use: date -u -v-30d '+%Y-%m-%dT%H:%M:%S')
aws ec2 describe-snapshots --owner-ids self \
  --query "Snapshots[?StartTime<='$(date -u -d '30 days ago' '+%Y-%m-%dT%H:%M:%S')'].{ID:SnapshotId, Date:StartTime, Size:VolumeSize}" \
  --output table
```

> `date -d` is GNU syntax (Linux, CloudShell). macOS `date` fails with `date: illegal option -- d`; use `-v-30d`, `-v-1m` or `-v-1H` there, or `gdate` from Homebrew coreutils.

### Copy a Snapshot (Cross-Region)

```sh
# Copy to another region (run from the destination region)
aws ec2 copy-snapshot \
  --region eu-west-1 \
  --source-region us-east-1 \
  --source-snapshot-id snap-0abc123 \
  --description "DR copy"

# Time-based copy: finish within a set time (15-minute steps, up to 2,880 minutes)
aws ec2 copy-snapshot \
  --region eu-west-1 \
  --source-region us-east-1 \
  --source-snapshot-id snap-0abc123 \
  --completion-duration-minutes 60 \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=dr-copy}]'
```

- User tags are **not** copied: add them with `--tag-specifications` (as above) or afterwards.
- Up to 20 concurrent copies per destination; more fail with `ResourceLimitExceeded`.
- The first copy to another Region or a new KMS key is a full copy; later ones are incremental while the previous copy still exists.
- Copies don't inherit fast snapshot restore.

### Multi-Volume Snapshots

```sh
# Crash-consistent snapshots of all volumes of an instance at the same point in time
# (use this for RAID sets and databases spread over several volumes)
aws ec2 create-snapshots \
  --instance-specification InstanceId=i-0abc123,ExcludeBootVolume=true \
  --copy-tags-from-source volume \
  --description "Multi-volume backup"
```

### Share a Snapshot

```sh
# Share with another account
aws ec2 modify-snapshot-attribute --snapshot-id snap-0abc123 \
  --attribute createVolumePermission --operation-type add --user-ids 111122223333

# Stop sharing
aws ec2 modify-snapshot-attribute --snapshot-id snap-0abc123 \
  --attribute createVolumePermission --operation-type remove --user-ids 111122223333

# Who can use it
aws ec2 describe-snapshot-attribute --snapshot-id snap-0abc123 --attribute createVolumePermission

# Block public sharing for the Region (block-new-sharing keeps existing public snapshots public)
aws ec2 enable-snapshot-block-public-access --state block-all-sharing
aws ec2 get-snapshot-block-public-access-state
```

- Snapshots encrypted with the AWS managed key (`aws/ebs`) **cannot** be shared. Use a customer managed key and share the key too.
- Only unencrypted snapshots can be made public (`--group-names all`).

### Delete Snapshots

```sh
# Delete a snapshot
aws ec2 delete-snapshot --snapshot-id snap-0abc123

# Delete all snapshots for a volume
aws ec2 describe-snapshots --owner-ids self \
  --filters "Name=volume-id,Values=vol-0abc123" \
  --query "Snapshots[].SnapshotId" --output text | \
  xargs -n1 aws ec2 delete-snapshot --snapshot-id

# A snapshot used by a registered AMI can't be deleted: find the AMI and deregister it first
aws ec2 describe-images --owners self \
  --filters "Name=block-device-mapping.snapshot-id,Values=snap-0abc123" \
  --query "Images[].ImageId" --output text
aws ec2 deregister-image --image-id ami-0abc123
```

### Snapshot Lifecycle with DLM

```sh
# Create the default DLM role once per account (AWSDataLifecycleManagerDefaultRole)
aws dlm create-default-role --resource-type snapshot

# Create a lifecycle policy (daily snapshots at 03:00 UTC, retain 7)
aws dlm create-lifecycle-policy \
  --description "Daily EBS snapshots" \
  --state ENABLED \
  --execution-role-arn arn:aws:iam::123456789012:role/AWSDataLifecycleManagerDefaultRole \
  --policy-details '{
    "PolicyType": "EBS_SNAPSHOT_MANAGEMENT",
    "ResourceTypes": ["VOLUME"],
    "TargetTags": [{"Key": "Backup", "Value": "true"}],
    "Schedules": [{
      "Name": "DailySnapshot",
      "CreateRule": {"Interval": 24, "IntervalUnit": "HOURS", "Times": ["03:00"]},
      "RetainRule": {"Count": 7},
      "CopyTags": true
    }]
  }'

# List lifecycle policies
aws dlm get-lifecycle-policies --output table
```

### Snapshot Lock

Lock snapshots to prevent deletion for compliance and data retention. No extra charge.

| Mode | Behavior |
|------|----------|
| Governance | Locked against deletion by all users. IAM users with proper permissions can extend/shorten duration, delete lock, or change to Compliance mode. |
| Compliance | Locked against deletion by root and all IAM users. After the optional cooling-off period (1–72 hours), the lock cannot be removed until it expires. Duration can be extended but not shortened. |

`--lock-duration` is in days (1–36,500) and `--cool-off-period` in hours (1–72, compliance mode only). `unlock-snapshot` works on governance locks and on compliance locks still in the cooling-off period.

```bash
# Lock a snapshot in governance mode (1 year)
aws ec2 lock-snapshot --snapshot-id snap-0abc123 \
  --lock-mode governance --lock-duration 365

# Lock a snapshot in compliance mode (5 years, 24h cooling-off)
aws ec2 lock-snapshot --snapshot-id snap-0abc123 \
  --lock-mode compliance --lock-duration 1825 \
  --cool-off-period 24

# Unlock a governance-mode snapshot
aws ec2 unlock-snapshot --snapshot-id snap-0abc123

# Describe locked snapshots
aws ec2 describe-locked-snapshots

# Describe lock status for a specific snapshot
aws ec2 describe-locked-snapshots --snapshot-ids snap-0abc123
```

Notes:
- Locked snapshots can still be shared, copied, or archived
- If using customer-managed KMS keys, ensure the key remains valid for the lock duration
- AWS Backup independently manages retention — locking Backup-created snapshots is not recommended

### Snapshot Archive

Archived snapshots become full (not incremental) snapshots in a cheaper tier, for data kept 90 days or longer and rarely restored.

```sh
# Archive a snapshot
aws ec2 modify-snapshot-tier --snapshot-id snap-0abc123 --storage-tier archive

# Archive / restore progress
aws ec2 describe-snapshot-tier-status --filters "Name=snapshot-id,Values=snap-0abc123"

# Restore for 5 days (stays in the archive too), or move it back for good
aws ec2 restore-snapshot-tier --snapshot-id snap-0abc123 --temporary-restore-days 5
aws ec2 restore-snapshot-tier --snapshot-id snap-0abc123 --permanent-restore

# List archived snapshots
aws ec2 describe-snapshots --owner-ids self --filters "Name=storage-tier,Values=archive" \
  --query "Snapshots[].{ID:SnapshotId, Size:VolumeSize, Date:StartTime}" --output table
```

| | Standard tier | Archive tier |
|---|---|---|
| Storage (us-east-1) | $0.05 per GB-month | $0.0125 per GB-month (up to 75% less) |
| Restore | n/a | $0.03 per GB restored |
| Minimum period | none | 90 days (pro-rated charge if deleted or permanently restored earlier) |
| Use directly | create volumes, copy, share | restore to standard tier first |

### Recycle Bin

Retention rules keep deleted snapshots (1–365 days), EBS-backed AMIs (1–365 days) and volumes (1–7 days) so they can be recovered.
Deleted resources are billed at their normal rate while in the bin.

```sh
# Keep every deleted snapshot in this Region for 7 days
aws rbin create-rule \
  --resource-type EBS_SNAPSHOT \
  --retention-period RetentionPeriodValue=7,RetentionPeriodUnit=DAYS \
  --description "Keep deleted snapshots 7 days"

# Keep deleted volumes for 3 days
aws rbin create-rule \
  --resource-type EBS_VOLUME \
  --retention-period RetentionPeriodValue=3,RetentionPeriodUnit=DAYS

# List rules
aws rbin list-rules --resource-type EBS_SNAPSHOT

# Find and recover deleted resources
aws ec2 list-snapshots-in-recycle-bin
aws ec2 restore-snapshot-from-recycle-bin --snapshot-id snap-0abc123
aws ec2 list-volumes-in-recycle-bin
aws ec2 restore-volume-from-recycle-bin --volume-id vol-0abc123
```

### Multi-Region Snapshot and Volume Queries

```bash
# Find snapshots older than 1 month across all regions (GNU date; macOS: date -u -v-1m '+%Y-%m-%d')
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]'); do
  echo "$REGION"
  aws ec2 describe-snapshots --owner-ids self --region $REGION \
    --query "Snapshots[?(StartTime<='$(date -u -d '1 month ago' '+%Y-%m-%d')')].{ID:SnapshotId,Time:StartTime,Details:Description}" \
    --output table
done

# Find publicly shared snapshots across all regions (own snapshots restorable by "all")
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]'); do
  echo "$REGION:"
  aws ec2 describe-snapshots --owner-ids self --restorable-by-user-ids all --region $REGION \
    --query 'Snapshots[].{ID:SnapshotId,Volume:VolumeId,Date:StartTime}' \
    --output table
done

# Find unattached volumes across all regions
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]'); do
  echo "$REGION"
  aws ec2 describe-volumes --filters "Name=status,Values=available" --region $REGION \
    --query 'Volumes[*].{VolumeID:VolumeId,Size:Size,Type:VolumeType,AZ:AvailabilityZone}' \
    --output table
done

# Find volumes in error state across all regions
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]'); do
  echo "$REGION"
  aws ec2 describe-volumes --filters "Name=status,Values=error" --region $REGION \
    --query 'Volumes[*].{VolumeID:VolumeId,Size:Size,Type:VolumeType,AZ:AvailabilityZone}' \
    --output table
done

# Find volumes currently being modified (optimizing) across all regions
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]'); do
  echo "$REGION"
  aws ec2 describe-volumes-modifications --region $REGION \
    --filters 'Name=modification-state,Values=optimizing' \
    --query 'VolumesModifications[].{VolumeID:VolumeId,TargetSize:TargetSize,OriginalSize:OriginalSize,Progress:Progress}' \
    --output table
done
```

## Encryption

```sh
# Create an encrypted volume
aws ec2 create-volume \
  --volume-type gp3 \
  --size 100 \
  --availability-zone us-east-1a \
  --encrypted

# Create with a custom KMS key
aws ec2 create-volume \
  --volume-type gp3 \
  --size 100 \
  --availability-zone us-east-1a \
  --encrypted \
  --kms-key-id arn:aws:kms:us-east-1:123456789012:key/abcd-1234

# Enable encryption by default (per region: repeat with --region for each one)
aws ec2 enable-ebs-encryption-by-default

# Check if encryption by default is enabled
aws ec2 get-ebs-encryption-by-default
```

> You cannot encrypt an existing unencrypted volume in-place. Snapshot it and create a new, encrypted volume from the snapshot.

### Encrypt an Existing Volume

```sh
# 1. Snapshot the unencrypted volume
aws ec2 create-snapshot --volume-id vol-0abc123 --description "Pre-encryption"

# 2. Create an encrypted volume directly from the unencrypted snapshot
#    (add --kms-key-id for a customer managed key)
aws ec2 create-volume \
  --snapshot-id snap-0abc123 \
  --volume-type gp3 \
  --availability-zone us-east-1a \
  --encrypted

# 3. Swap volumes (stop instance, detach old, attach new)

# Alternative: keep an encrypted snapshot too (also the way to re-encrypt with another key)
aws ec2 copy-snapshot \
  --source-region us-east-1 \
  --source-snapshot-id snap-0abc123 \
  --encrypted \
  --description "Encrypted copy"
```

## Multi-Attach (io1/io2 Only)

Share a volume across up to 16 Nitro instances in the same AZ:

```sh
# Create a multi-attach volume
aws ec2 create-volume \
  --volume-type io2 \
  --size 100 \
  --iops 10000 \
  --availability-zone us-east-1a \
  --multi-attach-enabled

# Attach to multiple instances
aws ec2 attach-volume --volume-id vol-0abc123 --instance-id i-instance1 --device /dev/xvdf
aws ec2 attach-volume --volume-id vol-0abc123 --instance-id i-instance2 --device /dev/xvdf
```

> Multi-Attach requires a cluster-aware filesystem (GFS2, OCFS2) or application-level locking. ext4/XFS will corrupt data.

## Tagging

```sh
# Tag a volume
aws ec2 create-tags --resources vol-0abc123 \
  --tags Key=Name,Value=data-vol Key=env,Value=prod Key=Backup,Value=true

# Tag a snapshot
aws ec2 create-tags --resources snap-0abc123 \
  --tags Key=Name,Value=daily-backup

# Find volumes missing the Backup tag
aws ec2 describe-volumes \
  --query "Volumes[?!Tags || !contains(Tags[].Key, 'Backup')].{ID:VolumeId, Size:Size, Instance:Attachments[0].InstanceId}" \
  --output table
```

## Performance

### gp3 Baseline vs Provisioned

| Parameter | gp3 Baseline (free) | gp3 Max (extra cost) |
|-----------|---------------------|----------------------|
| IOPS | 3,000 | 80,000 (max 500 IOPS per GiB, so 160 GiB or larger for 80,000) |
| Throughput | 125 MiB/s | 2,000 MiB/s (max 0.25 MiB/s per provisioned IOPS, so 8,000 IOPS or more for 2,000) |

The baseline is the same at any size, but extra IOPS and throughput are capped by those ratios.

### gp2 Burst Behavior

| Volume Size | Baseline IOPS | Burst IOPS | Burst Duration (full bucket) |
|-------------|---------------|------------|----------------|
| 1–33.33 GiB | 100 | 3,000 | 1,862 s (~31 min) |
| 100 GiB | 300 | 3,000 | 2,000 s (~33 min) |
| 750 GiB | 2,250 | 3,000 | 7,200 s (2 h) |
| 1,000 GiB | 3,000 | N/A (baseline = burst) | N/A |
| 5,334+ GiB | 16,000 | N/A (max) | N/A |

gp2 formula: 3 IOPS per GiB (minimum 100, max 16,000). The credit bucket holds 5.4 million I/O credits;
burst duration = credits / (3,000 − baseline IOPS).

### Monitor Volume Performance

```sh
# Check volume metrics (GNU date; macOS: date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ')
aws cloudwatch get-metric-statistics \
  --namespace AWS/EBS \
  --metric-name VolumeReadOps \
  --dimensions Name=VolumeId,Value=vol-0abc123 \
  --start-time $(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --end-time $(date -u '+%Y-%m-%dT%H:%M:%SZ') \
  --period 300 \
  --statistics Sum

# Key metrics to monitor
# VolumeReadOps / VolumeWriteOps     — IOPS consumed
# VolumeReadBytes / VolumeWriteBytes — Throughput consumed
# VolumeQueueLength                  — I/O requests waiting to complete
# VolumeAvgIOPS / VolumeAvgThroughput — average IOPS and KiB/s per minute (Nitro instances)
# VolumeIOPSExceededCheck            — 1 if the app tried to exceed provisioned IOPS (Nitro)
# VolumeThroughputExceededCheck      — 1 if the app tried to exceed provisioned throughput (Nitro)
# VolumeStalledIOCheck               — 1 if the volume failed the stalled I/O check (Nitro)
# VolumeThroughputPercentage         — % of provisioned IOPS delivered (io1/io2)
# VolumeConsumedReadWriteOps         — ops consumed, counted in 256 KiB units (io1/io2)
# BurstBalance                       — burst credits remaining in % (gp2, st1, sc1)
```

### Check Burst Balance (gp2)

```sh
aws cloudwatch get-metric-statistics \
  --namespace AWS/EBS \
  --metric-name BurstBalance \
  --dimensions Name=VolumeId,Value=vol-0abc123 \
  --start-time $(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --end-time $(date -u '+%Y-%m-%dT%H:%M:%SZ') \
  --period 300 \
  --statistics Average
```

If burst balance drops to 0%, you're throttled to baseline IOPS. Migrate to gp3 or increase volume size.

### Initialize Volumes Restored from Snapshots

Blocks of a volume created from a snapshot are pulled from S3 on first access, so first reads are slow. Three ways around it:

```sh
# 1. Provisioned initialization rate (100–300 MiB/s, billed per GiB of snapshot data)
aws ec2 create-volume \
  --snapshot-id snap-0abc123 \
  --volume-type gp3 \
  --availability-zone us-east-1a \
  --volume-initialization-rate 300

# 2. Fast snapshot restore: volumes from this snapshot in these AZs are fully initialized at creation
#    (max 5 snapshots per Region, snapshots up to 16 TiB, billed per snapshot per AZ per hour)
aws ec2 enable-fast-snapshot-restores --availability-zones us-east-1a us-east-1b --source-snapshot-ids snap-0abc123
aws ec2 describe-fast-snapshot-restores --filters "Name=snapshot-id,Values=snap-0abc123" \
  --query "FastSnapshotRestores[].{AZ:AvailabilityZone, State:State}" --output table
aws ec2 disable-fast-snapshot-restores --availability-zones us-east-1a us-east-1b --source-snapshot-ids snap-0abc123
```

```sh
# 3. Read every block yourself (inside the instance; fio is much faster than dd).
#    The fio line ran as-is with fio 3.39 on Debian 13 (on a 1 GiB test device)
sudo fio --filename=/dev/nvme1n1 --rw=read --bs=1M --iodepth=32 --ioengine=libaio --direct=1 --name=volume-initialize
sudo dd if=/dev/nvme1n1 of=/dev/null bs=1M
```

With an initialization rate, the time depends on the snapshot's data (`FullSnapshotSizeInBytes`), not the volume size:
10 GiB of data at 300 MiB/s takes about 34 seconds. A rate given together with an FSR-enabled snapshot overrides FSR.

### EBS-Optimized Instances and Instance Limits

The instance type caps total EBS IOPS and throughput across all its volumes, whatever the volumes can do:

```sh
aws ec2 describe-instance-types --instance-types m7i.large r7g.4xlarge \
  --query "InstanceTypes[].{Type:InstanceType, Optimized:EbsInfo.EbsOptimizedSupport, MaxIOPS:EbsInfo.EbsOptimizedInfo.MaximumIops, MaxMBps:EbsInfo.EbsOptimizedInfo.MaximumThroughputInMBps, NVMe:EbsInfo.NvmeSupport}" \
  --output table
```

`EbsOptimizedSupport` is `default` on current-generation types (always on, free). For smaller sizes the maximum is a burst
that lasts 30 minutes per 24 hours (`EBSIOBalance%` / `EBSByteBalance%` in the `AWS/EC2` namespace).

### RAID 0 (Striping)

Stripe identical volumes when one volume can't reach the IOPS or throughput the instance supports. Size, IOPS and throughput add up;
losing one volume loses the array. RAID 1/5/6 are not recommended on EBS (EBS already replicates, and parity or mirroring costs I/O).
Tested on Debian 13 (mdadm 4.4) with two 1 GiB loop devices standing in for EBS volumes; on an instance use
the NVMe devices from `lsblk` (`/dev/nvme1n1 /dev/nvme2n1`):

```console
$ sudo mdadm --create --verbose /dev/md0 --level=0 --name=MY_RAID --raid-devices=2 /dev/loop0 /dev/loop1
mdadm: chunk size defaults to 512K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.

$ cat /proc/mdstat
Personalities : [raid0]
md0 : active raid0 loop1[1] loop0[0]
      2093056 blocks super 1.2 512k chunks

$ sudo mkfs.ext4 -q -L MY_RAID /dev/md0
$ sudo mdadm --detail --scan
ARRAY /dev/md0 metadata=1.2 UUID=a427cbfb:e9883ad9:a0f5dcc9:c884081f
$ sudo mkdir -p /mnt/raid && sudo mount /dev/md0 /mnt/raid
$ df -h /mnt/raid
/dev/md0        2.0G  532K  1.9G   1% /mnt/raid
```

To reassemble at boot, append the `ARRAY` line to `/etc/mdadm/mdadm.conf` (Debian/Ubuntu) or `/etc/mdadm.conf`
(Amazon Linux, RHEL) with `sudo mdadm --detail --scan | sudo tee -a <file>`, and mount by label in `/etc/fstab`
with `nofail`: `LABEL=MY_RAID /mnt/raid ext4 defaults,nofail 0 2`. Snapshot the members with `create-snapshots`
(multi-volume) so the set is consistent.

### Read-Ahead for st1 and sc1

For large sequential reads through the page cache, AWS recommends 1 MiB read-ahead (2,048 × 512-byte sectors) on HDD
volumes instead of the 128 KiB default. Don't do this for small random I/O.

```sh
sudo blockdev --report /dev/nvme1n1          # RA column = read-ahead in sectors
sudo blockdev --setra 2048 /dev/nvme1n1
```

On the RAID 0 array above (an md device gets its own value, here already 2 MiB):

```console
$ sudo blockdev --getra /dev/md0
4096
$ sudo blockdev --setra 2048 /dev/md0
$ sudo blockdev --getra /dev/md0
2048
```

The setting is lost on reboot; set it again from a udev rule or a systemd unit.

### Torn Write Prevention

All EBS volumes attached to Nitro instances support atomic (all-or-nothing) 4, 8 and 16 KiB writes on Linux, aligned to the
write size. MySQL/MariaDB (InnoDB) can then turn off the doublewrite buffer: AWS quotes up to 30% more transactions and up
to 50% lower write latency, at no extra cost. AWS tested it with ext4 `bigalloc` (16 KiB clusters, e2fsprogs 1.46.5+),
`O_DIRECT` and kernel 5.10+.

```sh
# The vendor-specific NVMe data holds the volume ID and the NTWPU/NTWPG/NTWPB torn-write fields
sudo nvme id-ns -v /dev/nvme1n1
```

## One-Liners

```sh
# Total EBS storage used (in GiB)
aws ec2 describe-volumes --query "sum(Volumes[].Size)" --output text

# Count volumes by type
aws ec2 describe-volumes --query "Volumes[].VolumeType" --output text | tr '\t' '\n' | sort | uniq -c

# Find largest volumes
aws ec2 describe-volumes \
  --query "sort_by(Volumes, &Size)[-5:].{ID:VolumeId, Size:Size, Type:VolumeType}" --output table

# Find all unencrypted volumes
aws ec2 describe-volumes --filters Name=encrypted,Values=false \
  | jq '.Volumes[] | .VolumeId, .Encrypted'

# Snapshot all volumes tagged for backup
# (--output text puts the IDs on one tab-separated line; GNU xargs ignores -n1 when -I is given)
aws ec2 describe-volumes --filters "Name=tag:Backup,Values=true" \
  --query "Volumes[].VolumeId" --output text | tr '\t' '\n' | \
  xargs -I {} aws ec2 create-snapshot --volume-id {} --description "Automated backup $(date +%F)"

# List all instances with their volume IDs and names
aws ec2 describe-instances \
  --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value|[0],InstanceId,BlockDeviceMappings[*].Ebs.VolumeId]" \
  --output text

# List volumes attached to the current instance (from inside the instance, IMDSv2)
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
aws ec2 describe-volumes \
  --filters Name=attachment.instance-id,Values=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id) \
  --output table
```

## Self-Provisioning a Volume from Inside an Instance

Create and attach a volume using instance metadata — useful in userdata scripts. New AMIs such as
Amazon Linux 2023 require IMDSv2, so every metadata call needs a session token (plain `curl` gets `401`):

```sh
# Get instance identity from metadata (IMDSv2)
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
imds() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/$1"; }
REGION=$(imds dynamic/instance-identity/document | jq -r .region)
AZ=$(imds meta-data/placement/availability-zone)
INSTANCE_ID=$(imds meta-data/instance-id)

# Create a volume in the same AZ
VOLUME_ID=$(aws ec2 create-volume \
  --volume-type gp3 \
  --size 50 \
  --region $REGION \
  --availability-zone $AZ \
  --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=data-$INSTANCE_ID}]" \
  | jq -r .VolumeId)

# Wait for volume to be available
aws ec2 wait volume-available --volume-ids $VOLUME_ID --region $REGION

# Attach to this instance
aws ec2 attach-volume \
  --device /dev/xvdf \
  --volume-id $VOLUME_ID \
  --instance-id $INSTANCE_ID \
  --region $REGION

# Wait for attachment
aws ec2 wait volume-in-use --volume-ids $VOLUME_ID --region $REGION

# Format and mount (inside the instance). On Nitro the volume shows up as NVMe
# (/dev/nvme1n1, ...), not /dev/xvdf; the by-id link carries the volume ID without the dash
DEV=/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${VOLUME_ID/-/}
until [ -e "$DEV" ]; do sleep 1; done
sudo mkfs.xfs "$DEV"
sudo mkdir -p /data
sudo mount "$DEV" /data
```

## EBS as Code

### Kubernetes: gp3 StorageClass (EBS CSI driver)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer   # create the volume in the AZ of the pod's node
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  type: gp3
  iops: "6000"
  throughput: "250"
  encrypted: "true"
  csi.storage.k8s.io/fstype: xfs
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: ebs-gp3
  resources:
    requests:
      storage: 100Gi
```

```console
$ kubectl apply --dry-run=server -f ebs-gp3.yaml
storageclass.storage.k8s.io/ebs-gp3 created (server dry run)
persistentvolumeclaim/data created (server dry run)
```

- `WaitForFirstConsumer` matters because volumes are AZ-scoped: with `Immediate`, the volume can be created in an AZ where the pod can't run.
- `parameters` values are strings. An unquoted `iops: 6000` is rejected (Kubernetes v1.35.0, k3s):
  `json: cannot unmarshal number into Go struct field StorageClass.parameters of type string`.
- Other driver parameters: `kmsKeyId`, `iopsPerGB` (not together with `iops`), `blockSize`, `ext4BigAlloc`, `volumeInitializationRate`.
  `allowVolumeExpansion: true` lets you grow a PVC by editing its size (Elastic Volumes underneath).
- The server dry run checks the objects against the API; the EBS CSI driver itself checks the parameters when it creates the volume.

### Terraform: Volume and Attachment

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "instance_id" { type = string }
variable "availability_zone" { type = string } # must match the instance's AZ

resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  type              = "gp3"
  size              = 100
  iops              = 6000
  throughput        = 250
  encrypted         = true

  tags = {
    Name   = "data-vol"
    Backup = "true"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/xvdf" # shows up as /dev/nvme1n1 on Nitro
  volume_id   = aws_ebs_volume.data.id
  instance_id = var.instance_id
}
```

Checked with Terraform v1.17.1 and hashicorp/aws v6.71.0 (`terraform init` and `terraform validate`, no AWS call). The
provider already enforces the gp3 limits; with `throughput = 3000`:

```console
$ terraform validate
Error: expected throughput to be in the range (125 - 2000), got 3000
```

The `Backup = "true"` tag is the one the DLM policy above targets.

## Gotchas

- **AZ-locked**: EBS volumes exist in a single AZ. You cannot attach a volume in `us-east-1a` to an instance in `us-east-1b`. Migrate via snapshot.
- **One attachment at a time** (unless multi-attach io1/io2). Detach before attaching elsewhere.
- **Modification limit**: A modification must reach `completed` before the next one, and a volume can be modified up to 4 times in a rolling 24-hour period.
- **gp2 burst depletion**: Small gp2 volumes (< 1 TiB) can run out of burst credits under sustained load. Migrate to gp3.
- **DeleteOnTermination**: Root volumes default to `DeleteOnTermination=true`. Additional volumes default to `false`. Verify before terminating instances, and change it on a running instance with:
  `aws ec2 modify-instance-attribute --instance-id i-0abc123 --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"DeleteOnTermination":false}}]'`
- **Snapshot is incremental**: Only changed blocks are stored after the first snapshot. Deleting a snapshot doesn't lose data — it redistributes blocks to remaining snapshots.
- **Encryption costs nothing extra on EBS**: minimal effect on latency, no EBS charge (customer managed KMS keys have their own KMS price). Enable it by default.
- **Nitro for full io2 performance**: All io2 volumes are Block Express. Nitro instances reach 256,000 IOPS; other instance types top out at 32,000.
- **Device names on Nitro**: Nitro instances use NVMe. `/dev/xvdf` appears as `/dev/nvme1n1`. Use `lsblk` or `nvme list` to find the mapping.

## See Also

- [AWS Lightsail Cheatsheet](/cheatsheet/aws-lightsail/): exporting a Lightsail snapshot to EC2 creates an AMI and an EBS snapshot.
- [Terraform Provisioners Guide](/posts/terraform-provisioners-guide/): formats and mounts an `aws_ebs_volume` from Terraform.
- [Terraform Cheatsheet](/cheatsheet/terraform-cheatsheet/): the Terraform commands behind the snippet above.
- [Kubernetes emptyDir Volumes](/posts/kubernetes-emptydir-volumes/): node-local scratch space, the opposite of an EBS-backed PVC.
