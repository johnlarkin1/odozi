# Odozi

Alright! This is the public facing Github repo for [odozi][https://odozi.app/].

You can download it on the App Store [here] or just search for `odozi` on your phone. The ASO should be decent given the name (although damn did I want odyssey). I'll talk about that later.

You should really just check out the [marketing page][https://odozi.app/] for more of the background. I built this for basically myself, my girlfriend, and my best friend from kindergarten. They like it and I figure in the age of ai, might as well open source it and let people fork it and let it rip.

A huge proponent of your data being your data... So all of this data is yours and lands on your phone. You can also export basically the `SwiftData` rows. More or less, and again, I might write it up in more detail, but the vast majority of this is powered by `SwiftData` which sits on top of `CoreData` under the hood and it's basically SwiftUI / Apple's wrapper around SQlite. So it's pretty nice.

If you're worried about space, yeah it's actually surprising light. Roughly, you can estimate the core `DailyEntry` object as taking up call it ~1.5KB - 2KB. The photos are not included in this and are obviously the bulk of the storage setup. We store the 800x800 thumbnails so call that roughly ~200kb per day if you're attaching it every day. Ok very back of the envelope, but I'd imagine it could take up ~100MB if you're doing every daily entry with one or two photos attached.

## Architecture

I won't go into it too much, because I'm assuming people are going to want it spoonfed to them in a custom manner from claude / codex / opencode. There were obviously some super annoying parts given the freaking restrictions Apple puts on "parental control" and really just doing the screentime detection and monitoring. Location permissions are (for better or for worse) a lot more robust and polished.

## Naming Rant

Yeah yeah, I know. Which one is it - odozi or odyssey?

Well I wanted `odyssey` but obviously i wasn't about to pay an arm and a leg for that domain vs just `odozi.app`. And the other benefit is that it's the only app on the app store with that name. So I didn't want to be nor intentionally become a SF/NYC tech bro meme about just slapping a z in the name for a software product but... constraints of side project budget.

---

Anyways, feel free to hit me up if any questions - you can use `john@odozi.app`
