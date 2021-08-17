---
---

![Avocado](../assets/avocado.png)

## Rationale

Have you ever felt that your function has a lot of load  
not exactly contributing to the core functionality?  

Caching, Logging, Assertions, Exception Handling -  
are some layers that fog the core functionality.  

Avocado Object principle tends to declutter core functionality,  
putting supporting features in different layers.

## What is Avocado Object?

Avocado Object has its seed as implementation of core functionality.  
The pulp are decorators of all kinds layering around the seed.  
The peel is a metaphor for common interface that all of them implement.

Avocado can be constructed by a factory method or a factory.  
Preferably in a container framework or by a factory method on interface.

Avocado Objects call each other, usually from the seed or  
in exceptional cases - from the other layers.

## Advantages and Disadvantages of AOs

### Advantages

- Core functionality is more visible and simpler
- Code is more flexible, easy to maintenance.
- Different laws can be applied to different layers
- Different modules are easier to interpret because of the common pattern

### Disadvantages

- More code
- More complexity

## Example

Let's take some big chunk of code as an example:

```kotlin
    override fun render(to: Context, attachments: List<File>, cache: MutableMap<String, BufferedImage>) =
        with(this@asIntermediateRenderable) {
            val attachment = attachments.firstOrNull()
            if (attachment == null || attachment.absolutePath.isEmpty()) {
                throw Exception("No attachment for image notes item")
            }
            val cacheKey = "ImageNotesItem_${attachment.name}"
            val image = cache.get(cacheKey)

            if (image != null) {
                val center = actualRect.orDefault().center.orDefault()
                val size = actualRect.orDefault().size.orDefault()
                to.drawImage(
                    image as CGImage, true, to = PRotatedRect(
                        PPoint(center.x, center.y),
                        PSize(size.width, size.height),
                        actualRect.orDefault().angle
                    )
                )
                return
            }

            val renderedImage = try {
                when (format) {
                    ImageNotesItem.Format.PNG -> ImageIO.read(attachment)
                    ImageNotesItem.Format.JPEG -> ImageIO.read(attachment)
                    ImageNotesItem.Format.PDF -> actualRect.orDefault().size.orDefault()
                        .run { renderPDFToImage(attachment, width, height, to.options?.scale) }
                    ImageNotesItem.Format.JPEG2000 -> {
                        ImageIO.read(attachment)
                    }
                    else -> throw UnSupportedImageFormat("Unsupported image format $format")
                }
            } catch (e: UnSupportedImageFormat) {
                val svg = javaClass.classLoader.getResource("placeholder.svg")!!.toURI().toString()
                val size = rect.orDefault().size.orDefault()
                renderToImage(svg, size.width.toInt(), size.height.toInt(), true)
            } catch (e: Exception) {
                val f = javaClass.classLoader.getResource("error.png")
                ImageIO.read(f)
            }
            if (image != null) {
                val center = actualRect.orDefault().center.orDefault()
                val size = actualRect.orDefault().size.orDefault()
                to.drawImage(
                    renderedImage, true, to = PRotatedRect(
                        PPoint(center.x, center.y),
                        PSize(size.width, size.height),
                        actualRect.orDefault().angle
                    )
                )

                cache[cacheKey] = renderedImage
            }
        }
```

This code is responsible for rendering images in GoodNotes Web Viewer.
It converts all formats to bitmap and then renders it on canvas.

It is over 50 lines of pure code.  
However, the core functionality is much simpler:

```kotlin
override fun render(to: Context, attachments: List<Attachment>, cache: RenderingCache) =
    with(this@asIntermediateRenderable) {
        val cgImage = CGImage()
        
        when (format) {
            // Tested that ImageIO can find the correct format to read the image (png & jpg)
            ImageNotesItem.Format.PNG -> cgImage.image = ImageIO.read(File(attachment.absolutePath))
            ImageNotesItem.Format.JPEG -> cgImage.image = ImageIO.read(File(attachment.absolutePath))
            ImageNotesItem.Format.PDF -> cgImage.image = actualRect.orDefault().size.orDefault()
                .run { renderPDFToImage(attachment.absolutePath, width, height, to.options?.scale) }
            ImageNotesItem.Format.JPEG2000 -> {
                // current need to pre-process with opj_decompress and read the bmp from the same folder
                cgImage.image = ImageIO.read(File(attachment.absolutePath))
            }
            else -> throw UnSupportedImageFormat("Unsupported image format $format")
        }
            
        val center = actualRect.orDefault().center.orDefault()
        val size = actualRect.orDefault().size.orDefault()
        to.drawImage(
            cgImage, hasTransparency, to = PRotatedRect(
                PPoint(center.x, center.y),
                PSize(size.width, size.height),
                actualRect.orDefault().angle
            )
        )
    }
```

We will create two Avocados from this code cutting around the natural layers -  
as caching or exception handling.

### AttachmentToImageConverter

First the Interface

```kotlin
interface AttachmentToImageConverter {
    fun convertAttachmentToImage(context: Context, imageNotesItem: ImageNotesItem, attachment: File): BufferedImage

    companion object {
        fun create(renderingCache: MutableMap<String, BufferedImage>) =
            AttachmentToImageConverterImpl()
                .let { AttachmentToImageConverterExceptionHandler(it) }
                .let { AttachmentToImageConverterCache(it, renderingCache) }
    }
}
```

Next, the core:

```kotlin
class AttachmentToImageConverterImpl : AttachmentToImageConverter {
    override fun convertAttachmentToImage(
        context: Context,
        imageNotesItem: ImageNotesItem,
        attachment: File
    ): BufferedImage =
        with(imageNotesItem) {
            when (format) {
                // Tested that ImageIO can find the correct format to read the image (png & jpg)
                ImageNotesItem.Format.PNG -> ImageIO.read(attachment)
                ImageNotesItem.Format.JPEG -> ImageIO.read(attachment)
                ImageNotesItem.Format.PDF -> actualRect.orDefault().size.orDefault()
                    .run { renderPDFToImage(attachment, width, height, context.options?.scale) }
                ImageNotesItem.Format.JPEG2000 -> {
                    ImageIO.read(File(attachment.absolutePath))
                }
                else -> throw UnSupportedImageFormat("Unsupported image format $format")
            }
        }
}        
```

Exception Handling as a decorator:

```kotlin
class AttachmentToImageConverterExceptionHandler(val decorated: AttachmentToImageConverter) :
    AttachmentToImageConverter by decorated {

    override fun convertAttachmentToImage(
        context: Context,
        imageNotesItem: ImageNotesItem,
        attachment: File
    ): BufferedImage =
        try {
            decorated.convertAttachmentToImage(context, imageNotesItem, attachment)
        } catch (e: UnSupportedImageFormat) {
            val svg = javaClass.classLoader.getResource("placeholder.svg")!!.toURI().toString()
            val size = imageNotesItem.rect.orDefault().size.orDefault()
            renderToImage(svg, size.width.toInt(), size.height.toInt(), true)
        } catch (e: Exception) {
            val f = javaClass.classLoader.getResource("error.png")
            ImageIO.read(f)
        }
}
```

Finally, caching:

```kotlin
class AttachmentToImageConverterCache(
    val decorated: AttachmentToImageConverter,
    val cache: MutableMap<String, BufferedImage>
) :
    AttachmentToImageConverter by decorated {

    override fun convertAttachmentToImage(
        context: Context,
        imageNotesItem: ImageNotesItem,
        attachment: File
    ): BufferedImage {
        val cacheKey = "ImageNotesItem_${attachment.name}"
        val image = cache[cacheKey]

        if (image == null) {
            return decorated.convertAttachmentToImage(context, imageNotesItem, attachment)
        }

        return image
    }
}
```

### ImageToContextRenderer

Now the part responsible for rendering, let's speed it up.

```kotlin
interface ImageToContextRenderer {
    fun render(image: BufferedImage, to: Context, using: ImageNotesItem, attachment: File)

    companion object {
        fun create(renderingCache: MutableMap<String, BufferedImage>) =
            ImageToContextRendererImpl()
                .let { ImageToContextRendererCache(it, renderingCache) }
                .let { ImageToContextRendererGuard(it) }
    }
}

class ImageToContextRendererImpl : ImageToContextRenderer {
    override fun render(image: BufferedImage, to: Context, using: ImageNotesItem, attachment: File) {
        with(using) {
            val center = actualRect.orDefault().center.orDefault()
            val size = actualRect.orDefault().size.orDefault()
            to.drawImage(
                image, true, to = PRotatedRect(
                    PPoint(center.x, center.y),
                    PSize(size.width, size.height),
                    actualRect.orDefault().angle
                )
            )
        }
    }
}

class ImageToContextRendererCache(val decorated: ImageToContextRenderer, val cache: MutableMap<String, BufferedImage>) :
    ImageToContextRenderer by decorated {
    override fun render(image: BufferedImage, to: Context, using: ImageNotesItem, attachment: File) {
        decorated.render(image, to, using, attachment);

        val cacheKey = "ImageNotesItem_${attachment.name}"
        cache[cacheKey] = image
    }
}

class ImageToContextRendererGuard(val decorated: ImageToContextRenderer) :
    ImageToContextRenderer by decorated {
    override fun render(image: BufferedImage, to: Context, using: ImageNotesItem, attachment: File) {
        if (image != null)
            decorated.render(image, to, using, attachment);
    }
}
```

### AttachmentToContextRenderer

And finally the one super avocado to use them all

```kotlin
interface AttachmentToContextRenderer {
    fun render(to: Context, attachments: List<File>, cache: MutableMap<String, BufferedImage>, using: ImageNotesItem)

    companion object {
        fun create() =
            AttachmentToContextRendererImpl()
                .let { AttachmentToContextRendererGuard(it) }
    }
}

class AttachmentToContextRendererImpl : AttachmentToContextRenderer {
    override fun render(
        to: Context,
        attachments: List<File>,
        cache: MutableMap<String, BufferedImage>,
        using: ImageNotesItem
    ) {
        val attachment = attachments.first()
        val attachmentToImageConverter = AttachmentToImageConverter.create(cache)
        val imageToContextRenderer = ImageToContextRenderer.create(cache)

        attachmentToImageConverter.convertAttachmentToImage(to, using, attachment).also {
            imageToContextRenderer.render(it, to, using, attachment)
        }
    }
}

class AttachmentToContextRendererGuard(val decorated: AttachmentToContextRenderer) : AttachmentToContextRenderer {
    override fun render(to: Context, attachments: List<File>, cache: MutableMap<String, BufferedImage>, using: ImageNotesItem) {
        val attachment = attachments.firstOrNull()
        if (attachment == null || attachment.absolutePath.isEmpty()) {
            throw Exception("No attachment for image notes item")
        }

        decorated.render(to, attachments, cache, using)
    }
}
```

## Let's discuss

From 50 lines of code we got like a 80 lines now.  
Was it worth it?  
Some may say it is horrible approach and adds a lot of mental load.
From my perspective the code is structured better.  
It is predictable - we can expect what will be found in seperated classes.  
This pattern is easily reusable allowing us to be familiar with different parts of the application.  

What's more important, using this pattern teaches us how to code.  
It enforces us to create small, decorable classes that are easy to configure.  
We can see where we need to split class, where we can't easily decorate it -  
finding the golden line between too small and too big classes.  
Applied globally, it allows us to find common functionalities for each layer.  
We can also enforce rules differently for each layer (e.g using ArchUnit) -  
permitting usage only of needed functionality (like caching utilities in caching layer).

In my opinion if you are creating a small application, then this approach is not for you.  
Core functionality will be visible at first hand, even with some seldom supporting code.  
However, if you are thriving to grow, then you will need some hard foundation.  
Creating classes fogged by supportive functionality will slow you down and nest bugs.  
Creating well-structured objects will highlight important contexts and speed you up.  
Going enterprise? - use this pattern.