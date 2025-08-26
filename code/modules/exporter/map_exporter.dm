// code/modules/tools/map_exporter.dm
#ifdef MAP_EXPORTER
#include "##/tools/exporter/_defines.dm" // ensure our defines are visible; adjust include path if needed

// Helpers to compute chunk geometry
#define PXL_PER_TILE MAP_EXPORT_PIXELS_PER_TILE
#define TILES_PER_CH MAP_EXPORT_TILES_PER_CHUNK
#define CHUNK_PX (PXL_PER_TILE * TILES_PER_CH)

// Internal: safe stringify
/proc/_str(v) return "[v]"

// Write a BYOND resource (icon) to a file path
/proc/_save_icon_to(path, icon_or_resource)
    // BYOND will create directories as needed when using file()
    // fcopy_rsc copies a resource (icon) into a server-side file.
    // 'path' must be a text path like "data/exports/tiles/z1/0,0.png"
    var/dest = file(path)
    if (!isfile(dest))
        // even if it is not, fcopy_rsc will overwrite/create; we just ensure a clean target
        ;
    if (!fcopy_rsc(icon_or_resource, dest))
        world.log << "MAP_EXPORT: fcopy_rsc failed to write to [_str(path)]"
        return 0
    return 1

// Export a single chunk (16x16 tiles -> 512x512 PNG) starting at bottom-left (sx, sy) on z
/proc/export_map_chunk(sx, sy, z, include_lighting, outdir)
    if (!locate(sx, sy, z))
        return 0

    // CAPTURE_MODE_PARTIAL + range==16 yields exactly 16x16 map tiles, aligned at (sx,sy)
    var/icon/cap = null
    // generate_image signature from admin tool: (tx,ty,tz,range, mode, ?, ligths, ?)
    // We'll mirror it. Last arg '1' matched existing calls (keep behavior identical).
    cap = generate_image(sx, sy, z, TILES_PER_CH, CAPTURE_MODE_PARTIAL, null, include_lighting, 1)

    if (!cap)
        world.log << "MAP_EXPORT: generate_image returned null at [sx],[sy],z[z]"
        return 0

    // Filenames are zero-based grid indices (ix,iy)
    var/ix = round((sx - 1) / TILES_PER_CH)
    var/iy = round((sy - 1) / TILES_PER_CH)

    var/dirpath = "[outdir]/z[z]"
    var/filename = "[ix],[iy].png"
    var/path = "[dirpath]/[filename]"

    if (!_save_icon_to(path, cap))
        // attempt cleanup; BYOND GC will reclaim icon
        del(cap)
        return 0

    del(cap)
    return 1

// Export all chunks for a single z-level
/proc/export_z_level(z, include_lighting, outdir)
    if (!locate(1,1,z))
        world.log << "MAP_EXPORT: z[z] not present (no (1,1,z)). Skipping."
        return 0

    var/exported = 0
    // Walk in TILES_PER_CH steps to cover entire map
    for (var/sy = 1, sy <= world.maxy, sy += TILES_PER_CH)
        for (var/sx = 1, sx <= world.maxx, sx += TILES_PER_CH)
            // Skip fully-out-of-bounds chunks quickly
            if (!locate(sx, sy, z))
                continue
            if (export_map_chunk(sx, sy, z, include_lighting, outdir))
                exported++

    world.log << "MAP_EXPORT: z[z] exported [exported] chunks."
    return exported

  
/proc/export_index_json(outdir)
  var/list/zinfo = list()
  for (var/z=1, z<=world.maxz, z++)
      var/w = ceil(world.maxx / TILES_PER_CH)
      var/h = ceil(world.maxy / TILES_PER_CH)
      zinfo += list(list("z"=z, "chunks_w"=w, "chunks_h"=h, "px_per_chunk"=CHUNK_PX))
  var/meta = list("commit"=MAP_EXPORT_COMMIT, "z_levels"=zinfo)
  var/json = json_encode(meta)
  WRITE_FILE(file("[outdir]/index.json"), json)

  
  
// Export every present z-level
/proc/export_all_z(include_lighting, outdir)
    var/total = 0
    for (var/z = 1, z <= world.maxz, z++)
        total += export_z_level(z, include_lighting, outdir)
    world.log << "MAP_EXPORT: COMPLETE commit=" MAP_EXPORT_COMMIT " chunks=[total] outdir=[outdir]"
    export_index_json(outdir)
    return total

// Simple admin verb (available to anyone in MAP_EXPORTER builds) to run exporter interactively
/client/verb/MapExporter_Run(include_lighting as num|text)
    set name = "Map Exporter: Run"
    set category = "Server"
    var/inc = isnum(include_lighting) ? include_lighting : text2num("[include_lighting]")
    if (inc != 0) inc = 1
    to_chat(usr, "MAP_EXPORT: Starting (lighting=[inc]) …")
    export_all_z(inc, MAP_EXPORT_OUTDIR)
    to_chat(usr, "MAP_EXPORT: Done. Files under '[MAP_EXPORT_OUTDIR]'.")

// Autorun on world init (if enabled)
// We hook into world/New so a headless DreamDaemon run can produce files and quit.
var/global/__map_exporter_autorun_started = 0
/world/New()
    ..()
    #if MAP_EXPORT_AUTORUN
        if (!__map_exporter_autorun_started)
            __map_exporter_autorun_started = 1
            spawn(1)
                world.log << "MAP_EXPORT: Autorun begin (commit=" MAP_EXPORT_COMMIT ", lighting=[MAP_EXPORT_INCLUDE_LIGHTING])"
                export_all_z(MAP_EXPORT_INCLUDE_LIGHTING, MAP_EXPORT_OUTDIR)
                // optional: quit the world after export for CI
                shutdown()
    #endif

#endif // MAP_EXPORTER
