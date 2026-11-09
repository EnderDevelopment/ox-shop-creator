# FiveM Shop Creator Resource

OX Shop Creator is an in-game FiveM resource for creating and managing ESX Legacy shops registered with ox_inventory. It supports admin permissions, shop NPCs and blips, item category metadata, job restrictions, opening-hour checks, and purchase statistics.

## Install

1. Place the resource folder in your server’s resources directory.
2. Confirm `es_extended`, `ox_lib`, and `ox_inventory` are installed and started before this resource.
3. In `server.cfg`, add `ensure ed_shopcreator` after those dependencies. If the folder has a different name, use that name instead.
4. Check `config.lua`. By default, only players whose ESX group is `admin` can use the creator.
5. Start or restart the server. Shop data and statistics are saved in `shops.json` inside the resource.

## Use

1. In game, run `/shopcreator` as an authorized admin.
2. Create a shop, set its name and location, or use **Use my position** to fill in your current coordinates and heading.
3. Configure its NPC, blip, opening hours, and job restrictions as needed. Enter job restrictions one per line in `job=minimum_grade` format, such as `police=0`.
4. Add item entries one per line in `item_name | price | category | stock` format, such as `water | 10 | general | 99`. Item names must match ox_inventory item names.
5. Save the shop. Players can interact within the configured distance and purchase through the ox_inventory shop interface. Use the saved-shop list to edit or delete shops, and **Stats** to view recorded purchases.

Category keys are attached to shop entries as item metadata; category labels are saved but are not used to create category tabs in the ox_inventory interface. Purchase-hour checks use the server’s local clock, while the client’s closed-shop prompt uses the in-game clock. Deleting a shop removes it from this resource; the notification advises restarting ox_inventory to clear its registered shop.

---

More FiveM resource projects by EnderDevelopment: https://github.com/EnderDevelopment

Project page: https://dash.enderdevelopment.com/community/6bd5babf-2cbe-49b5-9108-26f134c4eea4?utm_source=github&utm_medium=readme&utm_campaign=auto_publish&utm_content=6bd5babf-2cbe-49b5-9108-26f134c4eea4
