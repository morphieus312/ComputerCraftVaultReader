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
