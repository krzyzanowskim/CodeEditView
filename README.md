**Never finished** and abandoned attempt to build a text layout + text view. 

Re-inventing the wheel by implementing a custom text layout system on the CoreText framework. I learned a lot and **decided not to pursue this approach**. 

- LayoutManager
  - `LayoutManager` text layout manager. layout text from the `TextStorage`. Layout lines (fragments) of text at once.
- Model
  - text storage abstracted `Range`, `Position`, `SelectionRange`, etc
- TextStorage
  - `TextStorage` abstracted text storage interface
  - `TextStorageProvider` protocol for any text storage
  - `TextBufferStorageProvider` TextBuffer-based implementation of the text storage provider
  - `StringTextStorageProvider` String-based implementation of the text storage provider  
- CodeEditView
  - Text view (NSView)

## Contact

Get in touch via twitter [@krzyzanowskim](https://x.com/krzyzanowskim), mastodon [@krzyzanowskim@mastodon.social](https://mastodon.social/@krzyzanowskim)
