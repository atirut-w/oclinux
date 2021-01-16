function Note(frequency, length)
    return {frequency = frequency, length = length}
end

local notes = {
    Note(440, 0.1),
    Note(490, 0.1),
    Note(590, 0.1),
    Note(490, 0.1),
    Note(730, 0.4),
    Note(730, 0.4),
    Note(660, 0.8),

    Note(440, 0.1),
    Note(490, 0.1),
    Note(590, 0.1),
    Note(490, 0.1),
    Note(660, 0.4),
    Note(660, 0.4),
    Note(590, 0.4),
    Note(560, 0.1),
    Note(490, 0.2),

    Note(440, 0.1),
    Note(490, 0.1),
    Note(590, 0.1),
    Note(490, 0.1),
    Note(590, 0.6),
    Note(660, 0.2),
    Note(560, 0.6),
    Note(490, 0.2),
    Note(440, 0.2),

    Note(440, 0.2),
    Note(660, 0.2),
    Note(590, 0.2),
    Note(590, 0.6),
}

local words = {
    "Ne", "ver", "gon", "na", "give", "you", "up.", "Ne", "ver", "gon", "na", "let", "you", "down", "", ".", "Ne", "ver", "gon", "na", "run", "a", "round", "", "and", "de", "sert", "", "you"
}

for i=1,#notes do
    print(words[i])
    computer.beep(notes[i].frequency, notes[i].length)
end