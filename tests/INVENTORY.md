# fat95 test inventory

Generated from the docstrings by `tests/list_tests.py`. Refresh with `make test-list-update`; `test_documented.py` fails when it is stale.

<!-- TESTS:BEGIN -->

### Unit tests

Collected by `unittest discover`, run by `make test` on both CPU tiers.

#### `test_block_io.py`

Block I/O encodes offsets, splits requests and rejects short transfers.

| test | what it guards |
|---|---|
| `test_td64_requests_cross_four_gib` | TD64 preserves the high offset across 4 GiB for 512–4096-byte blocks. |
| `test_td64_large_lba_keeps_all_offset_bits` | Large LBAs retain every high-offset bit instead of wrapping at 4 GiB. |
| `test_maxtransfer_uses_whole_blocks` | Legacy requests round MaxTransfer down and advance the buffer and LBA. |
| `test_short_second_request_fails_whole_transfer` | A short later transfer stops I/O and fails the whole block request. |
| `test_scsi_ten_byte_count_does_not_wrap` | READ10/WRITE10 split 65536 blocks into 65535 and one, retaining the LBA. |

#### `test_clear_paths.py`

Scratch-register clear loops: GetDefVolName and ExamineAll must zero the record they own and nothing past it.

| test | what it guards |
|---|---|
| `test_default_name_clear_loop_preserves_surrounding_bytes` | GetDefVolName clears only up to the longword-rounded end of the record it fills, so the byte past that end keeps its previous value. |
| `test_exall_clears_each_entry_for_short_and_full_records` | ExamineAll zeroes every field of each record it emits, for short and full record types alike, and never writes past the buffer the caller gave it. |

#### `test_contracts.py`

Behaviour contracts for the FAT32 fast mount, observed through the device.

| test | what it guards |
|---|---|
| `test_c1_read_only_session_writes_nothing` | C1: mounting, reading the FAT and closing again issues no write at all, so a read-only session cannot wear or corrupt the card. |
| `test_c2_usable_count_skips_the_fat` | C2: a usable stored free-cluster count mounts the volume validated with no background job, which is what the fast mount is for. |
| `test_c3_unusable_count_falls_back_to_the_scan` | C3: a stored count of 0xffffffff means unknown, so the mount stays validating and schedules the scan instead of trusting it. |
| `test_c4_durable_marker_precedes_every_metadata_write` | C4: the durable 'counts are not valid' marker reaches the card and is flushed before any metadata write, so an interrupted session can never look clean. |
| `test_c5_crash_after_first_write_forces_a_scan` | C5: a card pulled after the first metadata write mounts validating, because the marker is down and the stored count must not be believed. |
| `test_c6_clean_close_restores_the_fast_path` | C6: a clean unmount republishes the count and lifts the marker, so the next mount is validated with no scan. |
| `test_c7_dirty_volume_leaves_dirty` | C7: a volume that arrived dirty is still dirty at close, so the handler never grants a clean state it did not verify itself. |
| `test_c8_write_protected_volume_is_never_written` | C8: with the medium write-protected, publishing a changed free count issues no write. |
| `test_c8_soft_locked_volume_is_never_written` | C8: with the volume soft-locked, publishing a changed free count issues no write. |
| `test_c9_unreadable_marker_is_not_recorded_as_down` | C9: a marker sector that cannot be read is not written, and the next attempt either retries it or fails closed; proceeding as if the marker were down is what it may not do. |
| `test_c9_marker_failure_stops_further_writes` | C9: after a marker failure Ok2Write refuses the volume and an error is recorded, so it cannot keep accepting writes it is unable to invalidate. |
| `test_c9_multiblock_marker_failure_retains_all_pending_blocks` | C9: when the marker fails with two blocks pending, neither block is written and both stay flagged dirty in the buffer, so nothing is silently dropped. |
| `test_c9_strict_no_metadata_while_the_marker_is_not_down` | C9: no pending metadata reaches the card while the marker write is failing. |
| `test_c9_failed_marker_write_is_not_recorded_as_down` | C9: a marker write that failed is not remembered as done, so the next write attempt retries it or fails closed. |
| `test_c9_failed_count_store_leaves_the_card_needing_a_scan` | C9: a free-count store that failed is not recorded as published, so the next mount still scans. |
| `test_c10_failed_fat_read_never_writes_invented_entries` | C10: a FAT window that could not be read is never written back, so a read error cannot push invented 'everything allocated' content onto the card. |
| `test_marker_does_not_recurse_through_a_foreign_dirty_single_buffer` | Own regression, shared-cache marker only: writing the marker evicts a foreign dirty block instead of recursing, the evicted block goes out before the marker, and the metadata goes out last. |
| `test_aborted_scan_does_not_publish_a_partial_count` | Own regression: a scan stopped by a read error does not publish the partial count it had reached. |
| `test_c12_failed_mount_keeps_no_buffers_for_the_next_medium` | C12: a mount that produced no volume writes nothing out and drops both caches, so one card's blocks cannot reach the next one. |
| `test_c12_failed_probe_keeps_no_buffers_for_the_next_medium` | C12: a probe that found no disk writes nothing out and drops both caches. |

#### `test_corrupt.py`

Malformed FAT entries and stale free-space metadata, using assembled routines.

| test | what it guards |
|---|---|
| `test_bad_cluster_and_end_markers_decode_without_following_them` | FAT12/16/32 bad and end markers become negative sentinels, with no I/O. |
| `test_stale_free_count_cannot_spin_on_full_fat` | An allocation scan stops when FAT is full despite FreeClusters claiming space. |
| `test_allocation_watchdog_still_finds_last_available_cluster` | The bounded scan reaches the last data cluster instead of rejecting early. |
| `test_corrupt_append_chain_stops_without_mutating_fat` | Cycles, free/reserved/bad entries and out-of-volume links reject append. |
| `test_valid_append_reaches_free_cluster_after_long_chain` | A valid chain visits every allocated cluster and appends the remaining free one. |
| `test_maximal_valid_chain_reaches_allocation_scan` | A chain using every data cluster reaches disk-full handling, not corruption. |
| `test_fat_read_failure_is_not_an_end_marker` | Missing FAT returns a latched read failure, never stale disk-full status. |
| `test_failed_fat_window_cannot_start_or_extend_a_chain` | Permanent or transient FAT32 lookup failure changes no allocation state. |

#### `test_dirty_bits.py`

Dirty-marker I/O ordering per FAT type, and what each failing step must do. No device is opened.

| test | what it guards |
|---|---|
| `test_first_direct_write_marks_both_copies_and_flushes_first` | The first write of a cycle marks both FAT copies dirty and flushes them before the payload goes out; a second write in the same cycle carries the payload alone. |
| `test_flush_restores_clean_only_after_data_barrier` | UpdateDisk restores the clean marks between two barriers and closes the cycle, so clean is published only once the payload is durable. |
| `test_incoming_dirty_card_never_becomes_clean` | A card that arrived dirty stays dirty through a write and a flush; the handler never cleans a state it did not verify. |
| `test_fat12_has_no_marker_io` | FAT12 carries no dirty marker, so a write and a flush produce the payload write alone. |
| `test_fat16_updates_cached_marker_without_other_changes` | The FAT16 marker flips exactly one bit of the cached first sector and the flush puts it back, leaving every other byte alone. |
| `test_fat32_updates_cached_marker_without_other_changes` | The FAT32 marker flips exactly one bit of the cached FAT32 sector and the flush puts it back, leaving every other byte alone. |
| `test_marker_write_failure_blocks_data` | A marker write that fails blocks the payload and latches the write fault, so no metadata reaches a card that does not know it is dirty. |
| `test_marker_barrier_failure_blocks_data` | A barrier that fails after the marker write blocks the payload and leaves both copies dirty, because the marker is not known to be durable. |
| `test_swap_after_initialization_blocks_all_old_card_writes` | A media generation bump between mount and write stops every I/O, so blocks meant for the old card cannot land on the new one. |
| `test_read_only_session_never_writes_marker` | A flush with nothing written issues no I/O at all: a read-only session never marks the card. |
| `test_second_copy_failure_blocks_data_and_latches_fault` | A failure on the second FAT copy blocks the payload and latches the fault, with the first copy already marked. |
| `test_swap_during_marker_read_never_writes_new_card` | A card swap noticed during the marker read aborts before any write, so the new card is left untouched. |
| `test_short_marker_write_blocks_data` | A marker write the device truncates counts as a failure: the payload is blocked and the fault latched. |
| `test_data_barrier_failure_never_restores_clean` | A barrier that fails before the clean marks are rewritten leaves them dirty and writes nothing. |
| `test_clean_copy_failure_returns_failed_flush_without_payload_retry` | A failure while restoring the clean marks reports a failed flush, leaves both copies dirty, latches the fault and blocks the next write instead of retrying the payload. |
| `test_clean_final_barrier_failure_keeps_cycle_pending_and_faulted` | A failing final barrier leaves the cycle pending and the fault latched, so the clean state is not claimed. |
| `test_first_fat_sector_pending_allocation_survives_marker_writes` | A pending allocation in the first FAT sector survives both marker writes and the clean restore, so marking dirty never overwrites FAT content. |
| `test_crash_before_flush_remount_observes_dirty` | A machine lost between the write and the flush leaves the card dirty, and the fresh mount refuses clean eligibility. |
| `test_new_mount_initialization_discards_old_cycle_eligibility` | InitDirtyState discards the eligibility, cycle and in-flight state of the previous medium. |
| `test_failed_mount_probe_cannot_retain_old_clean_eligibility` | A probe whose read failed still mounts, but without clean eligibility and without a latched fault, and it refuses the first write rather than leaving it unmarked. |
| `test_mixed_clean_copies_are_never_promoted_to_clean` | With one FAT copy clean and one dirty the volume is not eligible, and a write and flush leave both copies dirty. |
| `test_fsinfo_publication_failure_never_sets_clean` | An FSInfo write that failed leaves both markers dirty and latches the fault, so a count that never landed is not treated as published. |
| `test_unsupported_update_blocks_managed_payload` | Without the device UPDATE command the marker cannot be made durable, so the managed payload is blocked and the fault latched. |
| `test_device_rejecting_update_blocks_managed_payload` | A device answering IOERR_NOCMD to UPDATE has the capability flag cleared, the payload blocked and the fault latched. |
| `test_fat12_keeps_unsupported_update_behavior` | FAT12 has no marker to flush, so a device without UPDATE still writes the payload and latches no fault. |
| `test_physical_protection_blocks_marker_and_payload` | A physically write-protected medium takes no I/O at all and keeps its clean marks. |
| `test_software_protection_blocks_marker_and_payload` | A soft-locked volume takes no I/O at all and keeps its clean marks. |
| `test_close_after_swap_clears_all_marker_state_without_writes` | Closing after a media swap writes nothing to the new card and clears every marker state field. |
| `test_failed_mount_close_clears_all_marker_state` | Closing a mount that produced no volume writes nothing and clears every marker state field. |
| `test_secondary_probe_failure_allows_mount_but_not_unmarked_writes` | An unreadable second FAT copy still mounts and scans, but the first write is refused rather than written with only one copy marked. |
| `test_recovered_probe_failure_never_earns_clean` | A probe that failed once never earns clean afterwards, even when the following I/O succeeds. |
| `test_probe_allocation_failure_allows_mount_without_clean_eligibility` | An AllocMem failure during the probe still mounts, with no I/O, no fault and no clean eligibility. |
| `test_probe_media_change_is_not_degraded_to_unknown` | A media change during the probe is reported as a change with the fault latched, not degraded to an unknown marker state. |

#### `test_documented.py`

The suite describes itself: every test carries a description and the inventory in INVENTORY.md matches them.

| test | what it guards |
|---|---|
| `test_every_test_method_has_a_description` | Each test method and each test class carries a docstring, so the inventory can state what it guards. |
| `test_inventory_is_current` | The generated block in INVENTORY.md is what list_tests.py produces right now. |

#### `test_example.py`

The smallest complete test in the suite, kept as the worked example.

| test | what it guards |
|---|---|
| `test_ms_date_renders_a_packed_date` | MSDate2Str writes a packed FAT date as DD.MM.YYYY and leaves a1 past it. |

#### `test_helpers.py`

Helper outputs, saved registers and condition codes.

| test | what it guards |
|---|---|
| `test_give_file_info_all_attribute_bytes` | GiveFileInfo maps all 256 MS-DOS attribute bytes to the same AmigaDOS protection bits and returns with a2 and a3 untouched. |
| `test_examine_all_all_attribute_bytes` | ExamineAll skips the volume label for every attribute byte carrying bit 3, emits one record with the same protection bits for all the others, and never writes past the buffer. |
| `test_cache_init_list_sentinels_counters_registers_and_ccr` | CacheInit empties both buffer lists to their sentinel form and zeroes the in-use counters, carrying d0, d1 and a1 through with the other registers and the condition codes untouched. |
| `test_ms_date_string_all_packed_dates` | All 65536 dates yield ten DD.MM.YYYY bytes; a1 advances and saved registers survive. |

#### `test_integration.py`

Media generation, cache retention, scan completion and volume locking across the whole handler.

| test | what it guards |
|---|---|
| `test_stale_generation_blocks_io_even_without_change_flag` | A stale media generation blocks I/O on its own, without waiting for the device to report a change. |
| `test_retry_cannot_adopt_new_card_change_number` | A retry after a write failure keeps the original change number, so it cannot resume onto a card that was swapped in meanwhile. |
| `test_short_write_is_failure` | A device that transfers fewer bytes than asked is a write failure and latches the fault. |
| `test_fat_failure_retains_window` | A FAT write that failed keeps the window and its pending flag, so the change is retried instead of lost. |
| `test_one_dirty_copy_disables_fast_mount` | One dirty FAT copy is enough to refuse clean eligibility, and the probe that finds it only reads. |
| `test_close_after_swap_never_flushes_old_buffers` | Closing after a media swap writes no buffer of the old card and drops the FAT window. |
| `test_failed_single_buffer_eviction_keeps_original_slot` | A one-entry cache eviction that failed keeps the original block and its dirty flag, and does not read the replacement over it. |
| `test_failed_fat_eviction_keeps_original_window` | A FAT window eviction that failed keeps the original window position and its pending flag. |
| `test_failed_fat_read_never_invents_writable_entries` | A FAT read that failed leaves the window marked invalid instead of presenting invented entries as usable. |
| `test_update_disk_reports_flush_failure` | UpdateDisk reports a failed barrier to the caller and latches the write fault. |
| `test_failed_mount_close_discards_cache_without_volume_node` | A close with no volume node writes nothing and drops both the one-entry cache and the FAT window. |
| `test_no_media_close_discards_remaining_cache` | A close with no medium present writes nothing and drops both the one-entry cache and the FAT window. |
| `test_failed_update_stops_motor_on_same_medium` | A failed update on the same medium still stops the motor and clears the idle work flags. |
| `test_failed_update_does_not_stop_replacement_motor` | A failed update after a swap leaves the replacement medium's motor alone. |
| `test_unlock_does_not_hide_latched_write_fault` | Unlocking clears the soft lock but leaves the latched write fault and the write-protected state visible. |
| `test_failed_flush_clears_idle_work_without_clearing_dirty_buffers` | A flush that failed clears the idle work flags but keeps the buffers flagged dirty, so their content is not dropped. |
| `test_manual_diskchange_flushes_same_medium` | A manual disk change on the same medium flushes the pending buffer and leaves the card marked clean. |
| `test_failed_eviction_does_not_reclassify_file_buffer` | An eviction that failed leaves the buffer's kind, the per-kind counters and its place on the list as they were. |
| `test_fat_reserved_entry_unchanged_through_metadata_and_close` | The reserved FAT entry is byte-identical after a metadata write and a close, across all four FAT-copy writes. |
| `test_fat_write_preserves_reserved_entry_in_each_copy` | A FAT write carries the changed entry into both copies and leaves the reserved entry untouched in each. |
| `test_swap_during_marker_read_blocks_metadata` | A swap noticed during the marker read stops after that read and leaves the buffer dirty. |
| `test_foreign_single_eviction_failure_retains_both_buffers` | When evicting a foreign one-entry block fails, that block and the pending multi-block buffer both keep their content and dirty flags, and no payload is written. |
| `test_open_resets_prior_medium_state_on_failed_probe` | A failed probe on open resets every per-medium state field and records the new mount generation, without touching the device. |
| `test_scan_read_failure_does_not_publish_partial_count` | A scan stopped by a read failure does not complete, and the partial count it reached is never published. |
| `test_scan_directory_buffer_failure_does_not_complete` | A scan that cannot obtain a directory buffer does not complete and records no read failure. |
| `test_scan_allocation_failure_does_not_complete` | A scan that cannot allocate does not complete and issues no I/O. |
| `test_interrupted_scan_does_not_complete` | A scan the user aborts does not complete, so its count is not treated as known. |
| `test_update_publishes_count_after_metadata_barrier` | UpdateDisk marks, writes the metadata, publishes the real count behind a barrier and ends with a final flush. |
| `test_successful_scan_publishes_count_without_touching_reserved_entry` | A completed scan publishes its count and leaves the reserved FAT entry of both copies untouched. |
| `test_new_check_recovers_prior_plain_read_failure` | A new scan clears the read-failure count an earlier one left and publishes its result without a write fault. |
| `test_prior_plain_read_failure_does_not_block_known_count` | An earlier plain read failure does not stop a count the handler actually knows from being published. |
| `test_diskstatus_keeps_faulted_volume_write_protected` | DiskStatus on a faulted volume issues only the change-state and protection queries and keeps reporting write-protected although the medium itself is writable. |
| `test_softlock_flushes_accepted_metadata_before_locking` | A soft lock that is accepted flushes the pending metadata behind a barrier and stores the key, leaving the following close with nothing to write. |
| `test_softlock_failed_flush_retains_accepted_metadata` | A soft lock whose flush failed is not applied: the fault latches, the buffer stays dirty and the payload is not written. |
| `test_diskstatus_refreshes_physical_writability` | DiskStatus re-reads the device protection and promotes the volume back to writable when the medium is. |
| `test_promoted_volume_flushes_accepted_fat_change` | A volume promoted back to writable accepts a FAT change and flushes it to both copies with no fault. |
| `test_diskstatus_records_physical_protection_only` | DiskStatus records physical protection in the device flags and reports the volume write-protected. |
| `test_softlock_does_not_clear_physical_writability` | A soft lock leaves the physical writability flag set, so lifting the lock needs no fresh probe. |
| `test_unreported_transfer_length_fails_closed` | A driver reporting no error but no transferred length is treated as a failure: the fault latches, the volume goes write-protected, nothing is written and the buffer stays dirty. |
| `test_idle_flush_publishes_once_per_batch` | The idle flush publishes the count once per batch of metadata rather than once per block, and an idle flush with nothing pending issues no I/O at all. |
| `test_idle_flush_publishes_completed_scan_count` | The idle flush publishes the count a completed scan produced and clears the pending flag. |

#### `test_mutation_faults.py`

Failed FAT access stops mutation and reports failure to file operations.

| test | what it guards |
|---|---|
| `test_free_chain_stops_before_failed_entry` | An unreadable first link frees nothing and returns false. |
| `test_failed_free_keeps_an_unset_allocation_hint` | A first-link failure preserves NextFreeCluster=0 instead of publishing -1. |
| `test_free_chain_counts_only_the_successfully_freed_prefix` | A later read error retains prefix accounting without claiming rollback. |
| `test_delete_keeps_object_metadata_after_failed_free` | FreeObj fails without clearing the file size, first cluster or append hint. |
| `test_zero_truncate_preserves_metadata_on_read_error` | Truncate-to-zero keeps metadata when the first FAT lookup fails. |
| `test_partial_truncate_does_not_cut_at_a_failed_lookup` | Boundary lookup failure writes no false EOC and reports the read error. |
| `test_growth_does_not_report_old_size_as_success_on_read_error` | Growth reports failure, rather than partial disk-full success, on read error. |
| `test_disk_full_growth_still_returns_the_partially_allocated_size` | Disk full after one new cluster retains the established partial-resize result. |
| `test_missing_fat_does_not_turn_stale_disk_full_into_partial_resize` | Missing FAT during growth returns failure even after an earlier disk-full error. |
| `test_allocation_rejects_media_change_before_marking_new_cluster` | A generation change after lookup prevents marking and restores the free count. |
| `test_failed_predecessor_write_reports_failure_after_allocating_cluster` | A failed predecessor-window reload reports failure; the allocated cluster stays counted. |
| `test_entry_write_failure_latches_and_replaces_stale_disk_full` | A refused mutation invalidates scan success and replaces stale disk-full status. |

#### `test_resize.py`

File handles follow the replacement chain after truncate-to-zero and growth.

| test | what it guards |
|---|---|
| `test_truncate_at_eof_then_extend_retargets_handles` | Truncation resets both handles; growth points both at the new chain. |

#### `test_selector.py`

Partition selection from DosType bytes and device-name suffixes.

| test | what it guards |
|---|---|
| `test_device_name_uses_only_the_trailing_number` | Name selectors cover 0..254; absent digits select the first partition. |
| `test_registration_suffix_does_not_select_a_partition` | A trailing dot-number suffix is ignored when resolving the partition. |
| `test_out_of_range_names_fail_without_replacing_the_selector` | Values above 254, including overflowing digit runs, reject the mount. |
| `test_dos_type_byte_ignores_the_device_name` | Non-marker DosTypes select their low byte regardless of the device name. |

| test | what it guards |
|---|---|
| `test_selector_is_index_plus_one` | CF<n> and FAT\<n+1> both reach pe_PartIndex n. |
| `test_selector_zero_takes_the_lowest_index` | FAT\0 on partitioned media falls back to the lowest FAT index. |
| `test_absent_and_other_unit_entries_are_skipped` | A removed card's entry or another unit's never answers the index. |

| test | what it guards |
|---|---|
| `test_init_registers_fat0_to_fat12_and_the_device_scheme` | FAT\0..FAT\12 cover partition indexes 0..11, then 0x464154FF. |

#### `test_serialize.py`

SerializeDisk must propagate the result of flushing its changes.

| test | what it guards |
|---|---|
| `test_failed_flush_reports_failure` | A failed flush returns failure and preserves the device error. |
| `test_successful_flush_reports_success` | A successful flush still returns success. |

### Scripts

Not collected by `unittest`; each one is run on its own.

`gated` runs under `make test` and must exit 0. `handler-in-the-loop tier` is the tier `make test-amifuse` drives: `amifuse_suite.py` and `amifuse_media.py --suite` run there; other image scripts run by hand. `library` entries are imported by the others, never run.

| file | status | what it checks |
|---|---|---|
| `amifuse_bridge.py` | library for the handler-in-the-loop tier | Raw-FAT adapter between AmiFUSE's HandlerBridge and the fat95 handler, with the observer that records what reaches the device. Patches nothing on disk; the changes are made to the imported objects at runtime. |
| `amifuse_fuse.py` | handler-in-the-loop tier | Real FUSE mount, write, unmount and remount of the built handler, one run per image profile. |
| `amifuse_images.py` | library for the handler-in-the-loop tier | Reproducible FAT fixtures and the independent oracle that checks them: a pure-Python FAT parser plus fsck.fat and mtools. Images are unpartitioned regular files; never pass a device path. |
| `amifuse_io_ab.py` | handler-in-the-loop tier | A/B device-request counts between two handler binaries. Counts requests, not Amiga wall-clock time. |
| `amifuse_media.py` | handler-in-the-loop tier | Media removal and replacement under a running handler: the handler process is kept alive while the card is pulled, swapped or made to fail. |
| `amifuse_suite.py` | handler-in-the-loop tier | Packet-level matrix: the built 68020 handler is driven with real DOS packets against real FAT12, FAT16 and FAT32 images, and every result is read back in Python. Each case runs in a timed child process. |
| `audit_extenddir_check.py` | gated | Regression check: the '..' entry of a new directory names its parent, so the parent cluster survives MakeIntRef. |
| `audit_ptable_check.py` | gated | Regression check: the ptable wrappers act on d0, not on the condition codes exec.library's OpenLibrary happens to leave on the ROM-bootstrap retry. Each routine is driven with both flag polarities for both outcomes; the result must depend only on the returned base. |
| `harness.py` | library | Run assembled handler routines with mocked device and Exec calls. |
| `lsfsres_paging.py` | gated | lsfsres lists FileSystem.resource, so it walks the list under Forbid and prints from a copy; the pause between screenfuls must not reach the shell with the console left in RAW mode, and must not happen at all when either stream is redirected. Real assembled code from src/lsfsres.s, mocked dos.library and exec. |

<!-- TESTS:END -->
