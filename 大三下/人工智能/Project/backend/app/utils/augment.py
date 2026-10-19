from typing import Optional

import torchvision.transforms as T

DEFAULT_IMAGE_SIZE = 224


def get_train_transform(image_size: Optional[int] = None):
    if image_size is None:
        image_size = DEFAULT_IMAGE_SIZE
    return T.Compose([
        T.Resize((image_size, image_size)),
        T.RandomHorizontalFlip(p=0.5),
        T.RandomRotation(degrees=15),
        T.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.1),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])


def get_val_transform(image_size: Optional[int] = None):
    if image_size is None:
        image_size = DEFAULT_IMAGE_SIZE
    return T.Compose([
        T.Resize((image_size, image_size)),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
