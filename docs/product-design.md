# Native Mac Product Design

## Primary experience

The default interface should be optimized for users who want a strong panorama without understanding every Hugin parameter.

### Step 1 — Import

- Finder drag-and-drop and native file picker.
- Photos integration where permissions allow.
- Thumbnail sequence with capture time, focal length and orientation warnings.
- Automatic detection of likely unrelated images.

### Step 2 — Align

- One clear primary action.
- Human-readable stages: analyzing images, finding matches, cleaning points, optimizing geometry and preparing preview.
- Pause/cancel support.
- Warnings that explain weak overlap, repeated textures or missing metadata.

### Step 3 — Preview

- Fast proxy preview while full-resolution rendering remains deferred.
- Direct horizon adjustment.
- Projection choices with visual examples, not unexplained terminology alone.
- Crop handles with automatic largest-valid-region suggestion.
- Exposure and seam warnings that link to advanced controls.

### Step 4 — Export

- Presets: Web JPEG, Maximum Quality TIFF, Transparent PNG and Custom.
- Estimated dimensions, disk usage and processing time.
- Clear destination selection and reveal-in-Finder action.

## Advanced mode

Advanced controls remain available through an inspector or explicit workspace switch:

- image and lens parameters;
- control points;
- masks;
- optimizer variables;
- projection and field of view;
- exposure fusion and HDR;
- blending and remapping options;
- batch queue.

## Mac conventions

- Standard menu commands and keyboard shortcuts.
- Undo/redo for project edits.
- Quick Look thumbnails and recent-project support.
- Dark Mode and accessibility labels.
- Retina-aware previews.
- Drag-and-drop and Finder reveal actions.
- Native progress, cancellation and error presentation.
