# yy-business-cards

Business Cards is a printer system for QBox/QBX servers that lets players place printers, save a photo, adjust the crop with zoom/drag, and print usable business cards. Everything is done with target interactions — no commands needed.

Main features:
- Place printers anywhere with a live preview.
- Save a photo URL and crop/zoom before printing.
- Print multiple cards at once with configurable limits.
- Pickup protection so only the owner can use/remove their printer.
- Customizable preview size and image host rules.
- Front‑only/two‑sided toggle.

Fully integrated with ox_target + ox_inventory.

you can join our discord for support: https://discord.gg/PqaFRdkpxM

<img width="1866" height="748" alt="Screenshot 2026-01-04 120613" src="https://github.com/user-attachments/assets/f6ab081b-ec41-40d8-9837-f88a34d69aa6" />

<img width="1518" height="621" alt="Screenshot 2026-01-04 120707" src="https://github.com/user-attachments/assets/c6914e47-c1a8-4443-aefe-51086fa7834a" />

<img width="1075" height="764" alt="Screenshot 2026-01-06 124603" src="https://github.com/user-attachments/assets/a2fc60d5-a182-4158-a7aa-f420fc0fb461" />

<img width="1027" height="618" alt="Screenshot 2026-01-06 124623" src="https://github.com/user-attachments/assets/2dcd0c66-bc03-403f-8fd1-2994452441bb" />


Download Instructions:

- Download the script as a zip, extract it into your resources folder then add ensure yy-business-cards to your server.cfg.
- Run the business_printers.sql in your servers database.
- Add the items into your ox_inventory items.lua file.
    ['business_printer'] = {
        label = 'Printer',
        description = 'Place a printer to create business cards',
        weight = 1500,
        stack = false,
        close = true,
        consume = 0,
        server = {
            export = 'yy-business-cards.usePrinter'
        },
        client = {
            export = 'yy-business-cards.usePrinter'
        }
    },

    ['blank_business_card'] = {
        label = 'Blank Business Card',
        description = 'Blank card for printing',
        weight = 1,
        stack = true,
        close = true
    },

    ['business_card'] = {
        label = 'Business Card',
        description = 'Printed business card',
        weight = 1,
        stack = true,
        close = true,
        client = {
            image = 'business_card.png',
            export = 'yy-business-cards.useBusinessCard'
        }
    },
  
- Add the images from the png folder into ox_inventory.

ADDITIONAL TERMS FOR FIVEM/CFX.RE DISTRIBUTION:

1. This resource may be distributed via CFX.re Asset Escrow system
2. Commercial use is permitted with proper attribution
3. Modified versions must maintain original credits
4. Support is provided on a best-effort basis
5. No warranty is provided for production use
