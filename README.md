# Automated Vault Reader and GUI Interface

## This working lua script adds a couple of things
1. Working Dynamic Weight System for rarities and affixes in Vault Hunters 3 (and Wold's Vaults).
2. Adds a GUI interface with Basalt to allow for easy assigning of weights to found affixes and required weight to keep.
3. Adds a monitor display that adds a tracker for what the last decision was, the highest score found, and the lowest score found, as well as how many of each rarities have been found.

## Currently requires four peripherals and a redstone input:
  * local reader = peripheral.wrap("vaultreader_1")
      * This is the vault reader available from CC: Vault
  * local input = peripheral.wrap("sophisticatedstorage:barrel_0")
      * This is the initial storage item where items will be input (If you want to have it identify items, add the identification upgrade from Sophisticated Storage)
  * local recycler = peripheral.wrap("sophisticatedstorage:barrel_1")
      * This is the output storage that will either go in to a recycler or go to a storage that has the Recycler upgrade from Sophisticated Storage)
  * local output = peripheral.wrap("sophisticatedstorage:barrel_2")
      * This is the output storage of everything that is kept.
  * if redstone.getInput("back")
      * This is the face where the redstone will be fed to the main computer. I just used a Redstone Link from Create and put it on the back of the computer.
  
  # Images
![2025-04-10_06 34 30](https://github.com/user-attachments/assets/76e35ae0-0a9c-4076-93b4-f2051a37238f)
![2025-04-10_06 34 25](https://github.com/user-attachments/assets/8ed586fd-3e4e-423b-b0cc-6cb34316866c)
![2025-04-10_06 34 24](https://github.com/user-attachments/assets/41305466-0a2b-487f-a866-e6566b46d093)
![2025-04-10_06 34 19](https://github.com/user-attachments/assets/4d787e00-c9d8-4bd1-9611-962f7ad3a0ad)
![2025-04-10_06 34 10](https://github.com/user-attachments/assets/cdbceeac-9063-436e-9bc1-90df96b6e9a8)
