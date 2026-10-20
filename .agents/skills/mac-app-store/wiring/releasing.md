
## Mac App Store

`make release-mas` builds `dist/mas/<App>.app` without Sparkle (the App Store updates
the app), signs it with Apple Distribution and wraps it in `dist/mas/<App>-X.Y.Z.pkg`
signed with the installer certificate. The build embeds the provisioning profile and
adds the application and team identifier entitlements. Uploading runs on your Mac;
the release workflow does not do it.

1. Certificates: **Apple Distribution** and **Mac Installer Distribution** in your
   login keychain. `TEAM_ID` set.
2. App ID for the bundle identifier and a **Mac App Store** provisioning profile;
   download it.
3. Create the app record in App Store Connect.
4. Build and upload:

   ```bash
   MAS_PROVISIONING_PROFILE=~/Downloads/MyApp.provisionprofile make release-mas
   MAS_PROVISIONING_PROFILE=… NOTARY_KEY_PATH=AuthKey_X.p8 NOTARY_KEY_ID=X \
     NOTARY_ISSUER_ID=<uuid> make upload-mas
   ```

5. Keep `Bundle/PrivacyInfo.xcprivacy` accurate (see [RECIPES.md](RECIPES.md)), then
   submit for review in App Store Connect.
