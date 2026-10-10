# =============================================================================
# AgriSense — EfficientNet-Lite0 Training Notebook
# =============================================================================
#
# Copy this file into a Google Colab notebook (one cell per section).
# Train one crop at a time: Tomato first, then Chili, then Eggplant.
#
# Usage:
#   1. Change CROP_NAME and DATASET_PATH in Cell 2 (Configuration).
#   2. Run all cells.
#   3. The .tflite model is saved to Google Drive.
#
# =============================================================================


# ── Cell 1: Install Dependencies ─────────────────────────────────────────────

# !pip install -q tensorflow-hub scikit-learn tf-keras


# ── Cell 2: Configuration ────────────────────────────────────────────────────
# Change CROP_NAME for each crop. Start with "tomato".

CROP_NAME = "tomato"                          # "tomato" | "chilli" | "eggplant"
# CROP_NAME = "chilli"
# CROP_NAME = "eggplant"

import os

# ── Mount Google Drive ───────────────────────────────────────────────────────
from google.colab import drive
drive.mount("/content/drive")

BASE_DIR = "/content/drive/MyDrive/AgriSense"

# Some crops have the images nested in a subfolder rather than directly
# under the crop folder. Map each crop to its actual image-class root.
DATASET_SUBFOLDERS = {
    "tomato": "Plant_Village_Tomato_colorimagesonly",
    "chilli": "",       # class folders sit directly under chilli/
    "eggplant": "",     # class folders sit directly under eggplant/
}

_sub = DATASET_SUBFOLDERS.get(CROP_NAME, "")
DRIVE_DATASET_PATH = os.path.join(BASE_DIR, CROP_NAME, _sub) if _sub else os.path.join(BASE_DIR, CROP_NAME)
OUTPUT_DIR = os.path.join(BASE_DIR, "models")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── Optional Speedup: Copy to local Colab SSD (/content/) ────────────────────
# Set USE_LOCAL_SSD = True to copy dataset from Drive to fast local SSD once.
USE_LOCAL_SSD = True

if USE_LOCAL_SSD:
    import shutil
    LOCAL_DATASET = f"/content/{CROP_NAME}"
    if not os.path.exists(LOCAL_DATASET):
        print(f"Copying {CROP_NAME} dataset to local SSD for 10x faster I/O...")
        shutil.copytree(DRIVE_DATASET_PATH, LOCAL_DATASET)
        print("Done copying to local SSD!")
    DATASET_PATH = LOCAL_DATASET
else:
    DATASET_PATH = DRIVE_DATASET_PATH

# ── Hyperparameters ──────────────────────────────────────────────────────────
IMG_SIZE = 224
BATCH_SIZE = 32
SEED = 42
EPOCHS = 20
LEARNING_RATE = 0.0001  # Safe rate for end-to-end EfficientNet fine-tuning
TRAIN_RATIO = 0.70
VAL_RATIO = 0.15
TEST_RATIO = 0.15

print(f"Crop:     {CROP_NAME}")
print(f"Dataset:  {DATASET_PATH}")
print(f"Output:   {OUTPUT_DIR}")


# ── Cell 3: Imports ──────────────────────────────────────────────────────────

import numpy as np
import matplotlib.pyplot as plt
import tensorflow as tf
import tensorflow_hub as hub
import shutil
import json
import random

from pathlib import Path
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    accuracy_score,
    precision_recall_fscore_support,
)
from sklearn.model_selection import train_test_split

print(f"TensorFlow version: {tf.__version__}")
print(f"GPU available: {tf.config.list_physical_devices('GPU')}")


# ── Cell 4: Discover and Validate Dataset ────────────────────────────────────

def discover_classes(dataset_path, crop_name):
    """
    Walk the dataset directory and return a sorted list of class names.

    Tomato folders end with '_images' — the suffix is stripped to get the label.
    Eggplant 'README' and 'metadata' entries are skipped.
    Chili folders are used as-is.
    """
    dataset_dir = Path(dataset_path)
    if not dataset_dir.exists():
        raise FileNotFoundError(f"Dataset path does not exist: {dataset_path}")

    # Entries to always skip (eggplant documentation files)
    skip_names = {"README", "metadata", ".DS_Store", "__MACOSX"}

    raw_classes = []
    for entry in sorted(dataset_dir.iterdir()):
        if not entry.is_dir():
            continue
        if entry.name in skip_names:
            continue
        raw_classes.append(entry.name)

    if not raw_classes:
        raise ValueError(f"No class folders found in {dataset_path}")

    # Derive clean labels
    class_labels = []
    for folder_name in raw_classes:
        if crop_name == "tomato" and folder_name.endswith("_images"):
            label = folder_name[: -len("_images")]
        else:
            label = folder_name
        class_labels.append(label)

    return raw_classes, class_labels


raw_folders, class_labels = discover_classes(DATASET_PATH, CROP_NAME)

print(f"\nFound {len(raw_folders)} classes for '{CROP_NAME}':\n")
for folder, label in zip(raw_folders, class_labels):
    print(f"  {folder:<50s} → {label}")


# ── Cell 5: Count Images per Class ──────────────────────────────────────────

VALID_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def list_images(folder_path):
    """Return a list of image file paths in a folder (non-recursive)."""
    images = []
    folder = Path(folder_path)
    for file in folder.iterdir():
        if file.is_file() and file.suffix.lower() in VALID_EXTENSIONS:
            images.append(str(file))
    return sorted(images)


all_image_paths = []
all_image_labels = []
class_counts = {}

for class_index, folder_name in enumerate(raw_folders):
    folder_path = os.path.join(DATASET_PATH, folder_name)
    images = list_images(folder_path)
    class_counts[class_labels[class_index]] = len(images)

    for img_path in images:
        all_image_paths.append(img_path)
        all_image_labels.append(class_index)

total_images = len(all_image_paths)
print(f"\nTotal images: {total_images}\n")
print(f"{'Class':<45s} {'Count':>6s} {'Pct':>6s}")
print("-" * 60)
for label, count in class_counts.items():
    percentage = count / total_images * 100 if total_images > 0 else 0
    print(f"  {label:<43s} {count:>6d} {percentage:>6.2f}%")


# ── Cell 6: Train / Validation / Test Split ──────────────────────────────────

def split_dataset(image_paths, image_labels, seed=42):
    """
    Split into 70% train, 15% validation, 15% test.
    Stratified by class label. Fixed seed for reproducibility.
    """
    # First split: 70% train, 30% temp
    train_paths, temp_paths, train_labels, temp_labels = train_test_split(
        image_paths,
        image_labels,
        test_size=(1.0 - TRAIN_RATIO),
        random_state=seed,
        stratify=image_labels,
    )

    # Second split: 50/50 of the 30% → 15% validation, 15% test
    relative_val = VAL_RATIO / (VAL_RATIO + TEST_RATIO)
    val_paths, test_paths, val_labels, test_labels = train_test_split(
        temp_paths,
        temp_labels,
        test_size=(1.0 - relative_val),
        random_state=seed,
        stratify=temp_labels,
    )

    return (
        (train_paths, train_labels),
        (val_paths, val_labels),
        (test_paths, test_labels),
    )


(train_paths, train_labels), (val_paths, val_labels), (test_paths, test_labels) = (
    split_dataset(all_image_paths, all_image_labels, seed=SEED)
)

print(f"Train:      {len(train_paths):>5d} images ({len(train_paths)/total_images*100:.2f}%)")
print(f"Validation: {len(val_paths):>5d} images ({len(val_paths)/total_images*100:.2f}%)")
print(f"Test:       {len(test_paths):>5d} images ({len(test_paths)/total_images*100:.2f}%)")

# Verify no data leakage
train_set = set(train_paths)
val_set = set(val_paths)
test_set = set(test_paths)
assert len(train_set & val_set) == 0, "Leakage: train ∩ validation"
assert len(train_set & test_set) == 0, "Leakage: train ∩ test"
assert len(val_set & test_set) == 0, "Leakage: validation ∩ test"
print("\n✓ No data leakage between splits.")


# ── Cell 7: Build tf.data Pipelines ──────────────────────────────────────────

NUM_CLASSES = len(class_labels)


def load_and_preprocess(image_path, label):
    """Load a single image, resize to IMG_SIZE, and normalize to [0, 1]."""
    raw = tf.io.read_file(image_path)
    image = tf.image.decode_image(raw, channels=3, expand_animations=False)
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
    image = image / 255.0
    return image, label


def augment_training_image(image, label):
    """
    Apply robust augmentations to training images:
    1. Zoom into the leaf interior to eliminate laboratory background borders.
    2. Add outdoor lighting and color jitter so the model recognizes natural field sunlight.
    """
    # Zoom deeply into leaf interior so model NEVER learns the background
    image = tf.image.central_crop(image, central_fraction=0.75)
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])

    # Spatial flips
    image = tf.image.random_flip_left_right(image)
    image = tf.image.random_flip_up_down(image)

    # Lighting and outdoor color shifts
    image = tf.image.random_brightness(image, max_delta=0.20)
    image = tf.image.random_contrast(image, lower=0.75, upper=1.25)
    image = tf.image.random_saturation(image, lower=0.75, upper=1.25)
    image = tf.image.random_hue(image, max_delta=0.06)
    image = tf.clip_by_value(image, 0.0, 1.0)
    return image, label


def build_dataset(paths, labels, is_training=False):
    """Create a tf.data.Dataset from file paths and integer labels."""
    dataset = tf.data.Dataset.from_tensor_slices((paths, labels))

    if is_training:
        dataset = dataset.shuffle(buffer_size=len(paths), seed=SEED)

    dataset = dataset.map(load_and_preprocess, num_parallel_calls=tf.data.AUTOTUNE)

    if is_training:
        dataset = dataset.map(augment_training_image, num_parallel_calls=tf.data.AUTOTUNE)

    dataset = dataset.batch(BATCH_SIZE)
    dataset = dataset.prefetch(tf.data.AUTOTUNE)
    return dataset


train_dataset = build_dataset(train_paths, train_labels, is_training=True)
val_dataset = build_dataset(val_paths, val_labels, is_training=False)
test_dataset = build_dataset(test_paths, test_labels, is_training=False)

print(f"Datasets built: {NUM_CLASSES} classes")
print(f"  Train batches:      {tf.data.experimental.cardinality(train_dataset).numpy()}")
print(f"  Validation batches: {tf.data.experimental.cardinality(val_dataset).numpy()}")
print(f"  Test batches:       {tf.data.experimental.cardinality(test_dataset).numpy()}")


# ── Cell 8: Visualize Sample Images ──────────────────────────────────────────

def show_batch(dataset, n=9):
    """Show a grid of sample images from a dataset batch."""
    images, labels = next(iter(dataset))
    cols = min(n, 3)
    rows = (n + cols - 1) // cols
    fig, axes = plt.subplots(rows, cols, figsize=(4 * cols, 4 * rows))
    axes = axes.flatten() if n > 1 else [axes]
    for i in range(min(n, len(images))):
        axes[i].imshow(images[i].numpy())
        axes[i].set_title(class_labels[labels[i].numpy()], fontsize=10)
        axes[i].axis("off")
    for j in range(i + 1, len(axes)):
        axes[j].axis("off")
    plt.suptitle(f"{CROP_NAME.title()} — Training Samples", fontsize=14)
    plt.tight_layout()
    plt.show()

show_batch(train_dataset)


# ── Cell 9: Build Native Trainable EfficientNet ──────────────────────────────
import tf_keras as keras


def build_model(num_classes):
    """
    Build a native Keras EfficientNet with FULL training enabled:
      Input (224x224x3) → EfficientNetB0 (trainable=True) → Pooling → Dropout → Output

    Because this is native Keras (not an old TF1 hub binary), trainable=True
    is fully supported, allowing the convolutional filters to learn real leaf pathology.
    """
    base_model = keras.applications.EfficientNetB0(
        weights="imagenet",
        include_top=False,
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
    )

    # Fully unfreeze the base so it learns leaf textures directly
    base_model.trainable = True

    model = keras.Sequential([
        base_model,
        keras.layers.GlobalAveragePooling2D(name="avg_pool"),
        keras.layers.Dropout(0.3, name="dropout"),
        keras.layers.Dense(num_classes, activation="softmax", name="classifier"),
    ])

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


model = build_model(NUM_CLASSES)
model.summary()


# ── Cell 10: Train the Model ─────────────────────────────────────────────────

callbacks = [
    keras.callbacks.EarlyStopping(
        monitor="val_accuracy",
        patience=5,
        restore_best_weights=True,  # Guarantees the #1 highest-scoring epoch is kept, not the latest
        verbose=1,
    ),
    keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss",
        factor=0.5,
        patience=2,
        min_lr=1e-6,
        verbose=1,
    ),
]

print(f"\nTraining {CROP_NAME} model for up to {EPOCHS} epochs...\n")

history = model.fit(
    train_dataset,
    validation_data=val_dataset,
    epochs=EPOCHS,
    callbacks=callbacks,
)


# ── Cell 11: Plot Training History ───────────────────────────────────────────

def plot_history(history, crop_name):
    """Plot accuracy and loss curves for training and validation."""
    import matplotlib.ticker as mtick
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    # Accuracy
    ax1.plot(history.history["accuracy"], label="Train Accuracy", marker="o", markersize=4)
    ax1.plot(history.history["val_accuracy"], label="Val Accuracy", marker="s", markersize=4)
    ax1.set_title(f"{crop_name.title()} — Accuracy")
    ax1.set_xlabel("Epoch")
    ax1.set_ylabel("Accuracy")
    ax1.yaxis.set_major_formatter(mtick.PercentFormatter(1.0, decimals=0))
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Loss
    ax2.plot(history.history["loss"], label="Train Loss", marker="o", markersize=4)
    ax2.plot(history.history["val_loss"], label="Val Loss", marker="s", markersize=4)
    ax2.set_title(f"{crop_name.title()} — Loss")
    ax2.set_xlabel("Epoch")
    ax2.set_ylabel("Loss")
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.show()

plot_history(history, CROP_NAME)


# ── Cell 12: Evaluate on Test Set ────────────────────────────────────────────

print(f"\n{'='*60}")
print(f"  FINAL EVALUATION — {CROP_NAME.upper()} MODEL")
print(f"{'='*60}\n")

# Run evaluation with live progress bar (verbose=1)
print("Evaluating on unseen test set...")
test_loss, test_accuracy = model.evaluate(test_dataset, verbose=1)
print(f"\nTest Loss:     {test_loss:.4f}")
print(f"Test Accuracy: {test_accuracy * 100:.2f}%\n")

# Run predictions with live progress bar (verbose=1)
print("Generating predictions for classification report...")
predictions = model.predict(test_dataset, verbose=1)
all_pred_labels = np.argmax(predictions, axis=1)

# Extract ground-truth labels from test_dataset
all_true_labels = []
for _, labels_batch in test_dataset:
    all_true_labels.extend(labels_batch.numpy())

all_true_labels = np.array(all_true_labels)
all_pred_labels = np.array(all_pred_labels)

# Classification report
print(f"\n{'─'*60}")
print("Classification Report:\n")
print(classification_report(
    all_true_labels,
    all_pred_labels,
    target_names=class_labels,
    digits=3,
))

# Per-class metrics
precision, recall, f1, support = precision_recall_fscore_support(
    all_true_labels, all_pred_labels, average=None
)

print(f"\n{'─'*60}")
print("Per-Class Summary:\n")
print(f"  {'Class':<35s} {'Prec':>8s} {'Recall':>8s} {'F1':>8s} {'N':>5s}")
print(f"  {'-'*66}")
for i, label in enumerate(class_labels):
    print(
        f"  {label:<35s} {precision[i] * 100:>7.2f}% {recall[i] * 100:>7.2f}% "
        f"{f1[i] * 100:>7.2f}% {support[i]:>5d}"
    )


# ── Cell 13: Confusion Matrix ────────────────────────────────────────────────

def plot_confusion_matrix(true_labels, pred_labels, class_names, crop_name):
    """Plot a color-coded confusion matrix."""
    cm = confusion_matrix(true_labels, pred_labels)
    num = len(class_names)

    fig, ax = plt.subplots(figsize=(max(8, num * 1.2), max(6, num)))
    im = ax.imshow(cm, interpolation="nearest", cmap=plt.cm.Blues)
    ax.figure.colorbar(im, ax=ax)

    ax.set(
        xticks=np.arange(num),
        yticks=np.arange(num),
        xticklabels=class_names,
        yticklabels=class_names,
        ylabel="True Label",
        xlabel="Predicted Label",
        title=f"{crop_name.title()} — Confusion Matrix",
    )
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")

    # Annotate cells
    threshold = cm.max() / 2.0
    for i in range(num):
        for j in range(num):
            ax.text(
                j, i, format(cm[i, j], "d"),
                ha="center", va="center",
                color="white" if cm[i, j] > threshold else "black",
                fontsize=9,
            )

    plt.tight_layout()
    plt.show()
    return cm

cm = plot_confusion_matrix(all_true_labels, all_pred_labels, class_labels, CROP_NAME)


# ── Cell 14: Export to TFLite ────────────────────────────────────────────────

def export_tflite(model, crop_name, output_dir, class_labels_list):
    """Convert the Keras model to TFLite and save to Drive."""

    # Save Keras model first (backup)
    keras_path = os.path.join(output_dir, f"{crop_name}_model.keras")
    model.save(keras_path)
    print(f"Keras model saved: {keras_path}")

    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    tflite_path = os.path.join(output_dir, f"{crop_name}_model.tflite")
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)

    tflite_size_mb = os.path.getsize(tflite_path) / (1024 * 1024)
    print(f"TFLite model saved: {tflite_path} ({tflite_size_mb:.2f} MB)")

    # Save class labels as JSON (needed for Flutter inference)
    labels_path = os.path.join(output_dir, f"{crop_name}_labels.json")
    with open(labels_path, "w") as f:
        json.dump(class_labels_list, f, indent=2)
    print(f"Labels saved: {labels_path}")

    return tflite_path


tflite_path = export_tflite(model, CROP_NAME, OUTPUT_DIR, class_labels)


# ── Cell 15: Verify TFLite Model ─────────────────────────────────────────────

def verify_tflite(tflite_path, test_dataset, class_labels_list, num_samples=5):
    """Run a few test images through the TFLite model to verify it works."""
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"\nTFLite Model Verification:")
    print(f"  Input shape:  {input_details[0]['shape']}")
    print(f"  Input dtype:  {input_details[0]['dtype']}")
    print(f"  Output shape: {output_details[0]['shape']}")
    print(f"  Output dtype: {output_details[0]['dtype']}")

    # Test a few images
    images_batch, labels_batch = next(iter(test_dataset))
    print(f"\nSample predictions (TFLite):\n")

    count = min(num_samples, len(images_batch))
    correct = 0
    for i in range(count):
        input_data = np.expand_dims(images_batch[i].numpy(), axis=0).astype(np.float32)
        interpreter.set_tensor(input_details[0]["index"], input_data)
        interpreter.invoke()
        output_data = interpreter.get_tensor(output_details[0]["index"])

        predicted_index = np.argmax(output_data[0])
        confidence = output_data[0][predicted_index]
        true_index = labels_batch[i].numpy()

        match = "✓" if predicted_index == true_index else "✗"
        if predicted_index == true_index:
            correct += 1

        print(
            f"  {match} True: {class_labels_list[true_index]:<30s} "
            f"Pred: {class_labels_list[predicted_index]:<30s} "
            f"Conf: {confidence * 100:.2f}%"
        )

    print(f"\n  TFLite verification: {correct}/{count} correct")


verify_tflite(tflite_path, test_dataset, class_labels)


# ── Cell 16: Summary ─────────────────────────────────────────────────────────

print(f"\n{'='*60}")
print(f"  {CROP_NAME.upper()} TRAINING COMPLETE")
print(f"{'='*60}")
print(f"""
  Classes:        {NUM_CLASSES}
  Total images:   {total_images}
  Test accuracy:  {test_accuracy * 100:.2f}%
  Model file:     {os.path.join(OUTPUT_DIR, f'{CROP_NAME}_model.tflite')}
  Labels file:    {os.path.join(OUTPUT_DIR, f'{CROP_NAME}_labels.json')}

  Next steps:
    1. Download the .tflite and _labels.json files
    2. Place them in agrisense/assets/models/
    3. To train the next crop, change CROP_NAME in Cell 2
       and re-run all cells
""")


# ── Cell 17: Interactive Leaf Tester (Upload Any Photo) ─────────────────────
# Test your model right inside Colab using photos from your phone or computer.

from google.colab import files
from PIL import Image
import io

CONFIDENCE_THRESHOLD = 0.60  # Require at least 60% confidence for a decisive diagnosis

print(f" Upload a {CROP_NAME} leaf photo from your phone/computer to test...")
uploaded = files.upload()

for filename in uploaded.keys():
    # 1. Load and display the image
    img = Image.open(io.BytesIO(uploaded[filename])).convert("RGB")
    plt.figure(figsize=(4, 4))
    plt.imshow(img)
    plt.axis("off")
    plt.title(f"Uploaded: {filename}")
    plt.show()

    # 2. Resize to IMG_SIZE x IMG_SIZE and normalize to [0, 1]
    img_resized = img.resize((IMG_SIZE, IMG_SIZE))
    img_array = np.array(img_resized) / 255.0
    img_tensor = np.expand_dims(img_array, axis=0).astype(np.float32)

    # 3. Run inference through the exported TFLite model
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    interpreter.set_tensor(input_details[0]["index"], img_tensor)
    interpreter.invoke()
    preds = interpreter.get_tensor(output_details[0]["index"])[0]

    # 4. Rank Top-3 predictions
    top3_indices = np.argsort(preds)[::-1][:3]
    top_label = class_labels[top3_indices[0]]
    top_conf = preds[top3_indices[0]]

    print("\n" + "=" * 50)
    print(f"  DIAGNOSIS REPORT ({CROP_NAME.upper()})")
    print("=" * 50)

    # Safety Guardrail: check if confidence is too low/scattered
    if top_conf < CONFIDENCE_THRESHOLD:
        print(f" ⚠️ UNCERTAIN / LOW CONFIDENCE ({top_conf * 100:.2f}%)")
        print(f"    The model is not confident this is a valid {CROP_NAME} leaf.")
        print("    Please take a closer, clearer photo in good lighting.\n")
    else:
        print(f" 🎯 Diagnosis: {top_label}")
        print(f"    Confidence: {top_conf * 100:.2f}%\n")

    print(" Top Candidates:")
    for rank, idx in enumerate(top3_indices, 1):
        label = class_labels[idx]
        conf = preds[idx] * 100
        medal = "🥇 #1" if rank == 1 else f"   #{rank}"
        print(f"   {medal}: {label:<32s} {conf:>6.2f}%")
    print("=" * 50 + "\n")
