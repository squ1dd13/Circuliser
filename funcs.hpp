// great file this

inline bool checkEnabled() {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.squ1dd13.bb_pref_ting"];

    if([[[defaults dictionaryRepresentation] allKeys] containsObject:@"tweakEnabled"]) {
        return [defaults boolForKey:@"tweakEnabled"];
    }

    return true;
}