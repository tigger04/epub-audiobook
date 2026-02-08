<!-- Version: 1.0 | Last updated: 2026-02-08 -->

# EPUB Audiobook Player

## Primary Use Case

To play an e-book as if it were an audiobook using system text-to-speech. This includes the kinds of features a user will expect from an audiobook player, such as:

- Play, pause, stop, rewind, fast forward
- Adjust playback speed
- Bookmarking
- Chapter navigation (if applicable)
- Text highlighting synchronized with audio (optional)
- Remembering the last position in the text
- Sleep timer

## Secondary Use Cases

- Accessibility: Providing an alternative way for visually impaired users to consume written content.
- Multitasking: Allowing users to listen to their e-books while doing other activities, such as commuting, exercising, or doing household chores.
- Language Learning: Helping language learners improve their listening skills by allowing them to listen to the text while following along with the written content.
- Enhanced Reading Experience: Offering a new way for users to engage with their e-books, especially for those who may find it difficult to read large blocks of text in one sitting.
- Content Creation: Enabling authors and publishers to create audio versions of their e-books without the need for professional voice actors, making it easier and more cost-effective to produce audiobooks.
- Accessibility for Dyslexia: Providing an alternative reading experience for individuals with dyslexia, allowing them to listen to the text instead of reading it.
- Language Support: Supporting multiple languages and accents to cater to a diverse user base.

## Target Platform

- iOS 17+ (iPhone and iPad)
- Written in SwiftUI
- Leverages the OS text-to-speech functionality (AVSpeechSynthesizer) as much as possible

## MVP Scope

The MVP focuses on EPUB format only. PDF and plaintext support are deferred to post-MVP milestones.

## Non-Goals (for MVP)

- Streaming or downloading books from external services
- User accounts or cloud sync
- PDF or plaintext file support
- Custom TTS voice models
