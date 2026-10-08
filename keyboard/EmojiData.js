.pragma library
// Bundled emoji table: each entry is the emoji, then its searchable names.
var categories = [
    {id: "recent", icon: "schedule", label: "Recent", items: []},
    {id: "faces", icon: "mood", label: "Faces", items: [
        "😀 grinning face smile happy", "😃 smiley big eyes happy", "😄 smile grin laugh happy", "😁 beaming grin teeth", "😆 laughing squint", "😅 sweat smile relief nervous", "🤣 rofl rolling floor laughing", "😂 joy tears laugh lol",
        "🙂 slight smile", "🙃 upside down silly", "😉 wink", "😊 blush smile happy", "😇 angel halo innocent", "🥰 love hearts face adore", "😍 heart eyes love", "🤩 star struck wow",
        "😘 kiss blow love", "😗 kissing", "😚 kissing closed eyes", "😋 yum tasty delicious", "😛 tongue", "😜 wink tongue crazy", "🤪 zany goofy crazy", "😝 squint tongue",
        "🤗 hug hugging", "🤭 giggle hand over mouth oops", "🫢 peek surprised hand", "🤫 shush quiet secret", "🤔 thinking hmm", "🫡 salute", "🤐 zipper mouth secret", "🤨 raised eyebrow suspicious",
        "😐 neutral", "😑 expressionless", "😶 no mouth silent", "🫥 dotted line invisible", "😏 smirk", "😒 unamused", "🙄 eye roll", "😬 grimace awkward",
        "😮‍💨 exhale sigh relief", "🤥 lying pinocchio", "😌 relieved calm", "😔 pensive sad", "😪 sleepy", "🤤 drool", "😴 sleeping zzz tired", "😷 mask sick",
        "🤒 thermometer sick fever", "🤕 bandage hurt", "🤢 nauseated sick", "🤮 vomit", "🤧 sneeze", "🥵 hot", "🥶 cold freezing", "🥴 woozy drunk",
        "😵 dizzy", "🤯 mind blown exploding head", "🤠 cowboy", "🥳 party celebrate birthday", "🥸 disguise glasses", "😎 cool sunglasses", "🤓 nerd glasses", "🧐 monocle curious",
        "😕 confused", "🫤 diagonal mouth meh", "😟 worried", "🙁 frown", "😮 open mouth surprised", "😯 hushed", "😲 astonished shocked", "😳 flushed embarrassed",
        "🥺 pleading puppy eyes", "🥹 holding back tears touched", "😦 frowning open mouth", "😧 anguished", "😨 fearful scared", "😰 anxious sweat", "😥 sad relieved", "😢 cry tear sad",
        "😭 sob crying loud", "😱 scream fear", "😖 confounded", "😣 persevere", "😞 disappointed", "😓 downcast sweat", "😩 weary", "😫 tired",
        "🥱 yawn", "😤 triumph steam huff", "😡 angry mad red", "😠 angry", "🤬 swearing cursing", "😈 devil smiling imp", "💀 skull dead", "💩 poop",
        "🤡 clown", "👻 ghost", "👽 alien", "🤖 robot", "🫠 melting face", "🫨 shaking face"]},
    {id: "hands", icon: "waving_hand", label: "Gestures", items: [
        "👍 thumbs up like yes", "👎 thumbs down dislike no", "👏 clap applause", "🙌 raised hands celebrate", "🫶 heart hands love", "🤝 handshake deal", "🙏 pray please thanks folded hands", "👋 wave hello bye",
        "🤚 raised back hand", "🖐️ hand fingers splayed", "✋ raised hand stop high five", "🖖 vulcan spock", "👌 ok perfect", "🤌 pinched fingers italian", "🤏 pinching small", "✌️ victory peace",
        "🤞 crossed fingers luck", "🫰 hand index thumb", "🤟 love you gesture", "🤘 rock on horns", "🤙 call me shaka", "👈 point left", "👉 point right", "👆 point up",
        "👇 point down", "☝️ index up", "💪 muscle flex strong biceps", "🦾 mechanical arm", "✍️ writing hand", "💅 nail polish", "🤳 selfie", "👀 eyes look",
        "👁️ eye", "👂 ear", "👃 nose", "🧠 brain", "🫀 heart organ anatomical", "🦷 tooth", "👄 mouth lips", "👅 tongue",
        "💜 purple heart", "❤️ red heart love", "🧡 orange heart", "💛 yellow heart", "💚 green heart", "💙 blue heart", "🖤 black heart", "🤍 white heart",
        "🤎 brown heart", "💔 broken heart", "❤️‍🔥 heart on fire", "💕 two hearts", "💞 revolving hearts", "💖 sparkling heart", "💗 growing heart", "💘 heart arrow cupid",
        "🔥 fire lit hot", "✨ sparkles magic", "⭐ star", "🌟 glowing star", "💫 dizzy star", "🎉 party popper tada celebrate", "🎊 confetti ball", "✅ check mark done",
        "❌ cross x no", "💯 hundred perfect", "💥 boom collision", "💢 anger", "💤 zzz sleep", "💬 speech bubble chat", "👑 crown king queen", "🏆 trophy win"]},
    {id: "nature", icon: "pets", label: "Nature", items: [
        "🐈 cat", "🐱 cat face kitten", "🐕 dog", "🐶 dog face puppy", "🐭 mouse", "🐹 hamster", "🐰 rabbit bunny", "🦊 fox",
        "🐻 bear", "🐼 panda", "🐨 koala", "🐯 tiger", "🦁 lion", "🐮 cow", "🐷 pig", "🐸 frog",
        "🐵 monkey", "🙈 see no evil monkey", "🐔 chicken", "🐧 penguin", "🐦 bird", "🦆 duck", "🦉 owl", "🦇 bat",
        "🐺 wolf", "🐴 horse", "🦄 unicorn", "🐝 bee honey", "🦋 butterfly", "🐌 snail", "🐞 ladybug", "🐢 turtle",
        "🐍 snake", "🦎 lizard", "🐙 octopus", "🦀 crab", "🐠 fish tropical", "🐬 dolphin", "🐳 whale", "🦈 shark",
        "🌙 moon crescent night", "☀️ sun sunny", "⛅ sun cloud", "🌧️ rain cloud", "⛈️ thunderstorm", "❄️ snowflake snow", "🌈 rainbow", "🌊 wave water ocean",
        "🌸 cherry blossom flower", "🌻 sunflower", "🌹 rose", "🌷 tulip", "🌿 herb leaf", "🍀 clover luck", "🌲 evergreen tree", "🌵 cactus"]},
    {id: "food", icon: "restaurant", label: "Food", items: [
        "🍕 pizza", "🍔 burger hamburger", "🍟 fries", "🌭 hot dog", "🌮 taco", "🌯 burrito", "🥪 sandwich", "🥐 croissant",
        "🍞 bread", "🧀 cheese", "🍳 egg cooking", "🥞 pancakes", "🍜 ramen noodles", "🍝 spaghetti pasta", "🍣 sushi", "🍱 bento",
        "🍰 cake slice", "🎂 birthday cake", "🧁 cupcake", "🍩 donut", "🍪 cookie", "🍫 chocolate", "🍿 popcorn", "🍦 ice cream",
        "🍎 apple red", "🍌 banana", "🍓 strawberry", "🍇 grapes", "🍉 watermelon", "🍑 peach", "🥑 avocado", "🍅 tomato",
        "☕ coffee hot drink", "🍵 tea matcha", "🧋 bubble tea boba", "🥤 cup straw soda", "🍺 beer", "🍷 wine", "🥂 cheers champagne", "🧃 juice box"]},
    {id: "travel", icon: "flight", label: "Travel", items: [
        "🚗 car", "🚕 taxi", "🚌 bus", "🚲 bike bicycle", "🛴 scooter", "🚂 train", "✈️ airplane flight", "🚀 rocket launch",
        "🛸 ufo", "🚁 helicopter", "⛵ sailboat", "🚢 ship", "🏠 house home", "🏢 office building", "🏫 school", "🏥 hospital",
        "🏖️ beach", "🏔️ mountain", "🌋 volcano", "🗺️ map", "🧭 compass", "⛺ tent camping", "🌃 night city", "🌅 sunrise"]},
    {id: "objects", icon: "emoji_objects", label: "Objects", items: [
        "💡 light bulb idea", "📱 phone mobile", "💻 laptop computer", "🖥️ desktop computer", "⌨️ keyboard", "🖱️ mouse computer", "🎮 game controller gaming", "🎧 headphones",
        "🎵 music note", "🎶 music notes", "🎤 microphone", "📷 camera", "📺 television tv", "🔋 battery", "🔌 plug power", "💾 floppy disk save",
        "📁 folder", "📄 document page", "📌 pushpin pin", "📎 paperclip", "✂️ scissors", "🔒 lock locked", "🔑 key", "🔧 wrench tool",
        "🔨 hammer", "⚙️ gear settings", "🧪 test tube", "🔬 microscope", "📚 books", "✏️ pencil", "📝 memo note", "📅 calendar",
        "⏰ alarm clock", "⌛ hourglass", "💰 money bag", "🎁 gift present", "🛒 shopping cart", "🧸 teddy bear", "🎈 balloon", "🕯️ candle"]},
    {id: "symbols", icon: "emoji_symbols", label: "Symbols", items: [
        "➕ plus", "➖ minus", "➗ divide", "✖️ multiply", "♾️ infinity", "‼️ double exclamation", "❓ question", "❗ exclamation",
        "⚠️ warning", "🚫 prohibited no", "⛔ no entry", "✔️ check", "☑️ checked box", "🔁 repeat", "🔄 refresh arrows", "⬆️ up arrow",
        "⬇️ down arrow", "⬅️ left arrow", "➡️ right arrow", "↩️ return arrow", "🔔 bell notification", "🔕 bell off mute", "🔴 red circle", "🟢 green circle",
        "🔵 blue circle", "🟡 yellow circle", "🟣 purple circle", "⚫ black circle", "⚪ white circle", "©️ copyright", "®️ registered", "™️ trademark"]},
    {id: "flags", icon: "flag", label: "Flags", items: [
        "🏁 chequered flag race finish", "🚩 triangular flag", "🏳️ white flag", "🏴 black flag", "🏳️‍🌈 rainbow flag pride", "🏴‍☠️ pirate flag", "🇺🇸 united states usa flag", "🇬🇧 united kingdom uk flag",
        "🇨🇦 canada flag", "🇩🇪 germany flag", "🇫🇷 france flag", "🇪🇸 spain flag", "🇮🇹 italy flag", "🇯🇵 japan flag", "🇰🇷 south korea flag", "🇧🇷 brazil flag",
        "🇮🇳 india flag", "🇦🇺 australia flag", "🇲🇽 mexico flag", "🇪🇺 european union flag"]}
];
function glyph(entry) { return entry.split(" ")[0]; }
function glyphs(index) { return categories[index].items.map(glyph); }
// Return the emoji whose names contain every typed word, best prefix match first.
function search(query) {
    var words = query.toLowerCase().split(/\s+/).filter(function (w) { return w.length > 0; });
    if (words.length === 0) return [];
    var scored = [];
    categories.forEach(function (category) {
        category.items.forEach(function (entry) {
            var names = entry.split(" ").slice(1);
            var score = 0;
            var all = words.every(function (word) {
                var best = -1;
                names.forEach(function (name, at) {
                    if (name === word) best = Math.max(best, 3 - Math.min(at, 2) * 0.1);
                    else if (name.indexOf(word) === 0) best = Math.max(best, 2 - Math.min(at, 2) * 0.1);
                    else if (name.indexOf(word) > 0) best = Math.max(best, 1);
                });
                score += best;
                return best >= 0;
            });
            if (all) scored.push({emoji: glyph(entry), score: score});
        });
    });
    scored.sort(function (a, b) { return b.score - a.score; });
    var seen = {}, out = [];
    scored.forEach(function (item) { if (!seen[item.emoji]) { seen[item.emoji] = true; out.push(item.emoji); } });
    return out;
}
