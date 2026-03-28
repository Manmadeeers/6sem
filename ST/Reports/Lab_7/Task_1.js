const { Builder, Browser, By, Key, until } = require('selenium-webdriver')

async function runBelstuTest() {
    let driver = await new Builder().forBrowser(Browser.FIREFOX).build();

    try {
        console.log('--- Starting Tests for https://belstu.by/ ---');
        await driver.get('https://belstu.by/');

        await driver.manage().window().maximize();

        try {

            let searchInput = await driver.findElement(By.id('search-text'));
            console.log('SUCCESS: Element found by ID ("search-text").');

            let placeholder = await searchInput.getAttribute('placeholder');
            console.log(`Content/Attribute: Placeholder is "${placeholder}"`);

        } catch (e) {
            console.log('FAILED: Could not find element by ID "search-text".');
        }


        try {

            let logoLink = await driver.findElement(By.css('.header-logo a'));
            console.log('SUCCESS: Element found by CSS Selector (".header-logo a").');

            let href = await logoLink.getAttribute('href');
            console.log(`Content/Attribute: Logo link points to ${href}`);
        } catch (e) {
            console.log('FAILED: CSS Selector 1 failed.');
        }

         try {

            let topMenu = await driver.findElement(By.css('ul.top-menu > li:first-child'));
            console.log('SUCCESS: Element found by CSS Selector ("ul.top-menu > li:first-child").');

            let text = await topMenu.getText();
            console.log(`Content: First menu item text is "${text}"`);

        } catch (e) {
            console.log('FAILED: CSS Selector 2 failed.');
        }

        try {

            let abiturientSection = await driver.findElement(By.xpath("//a[contains(@class, 'main-nav__link') and contains(text(), 'Абитуриенту')]"));
            console.log('SUCCESS: Element found by XPath (Abiturient link).');
            console.log(`Content: Link text is "${await abiturientSection.getText()}"`);

        } catch (e) {
            console.log('FAILED: XPath 1 failed.');
        }

          try {

            let contactInfo = await driver.findElement(By.xpath("//div[@class='footer-contacts']//address"));
            console.log('SUCCESS: Element found by XPath (Footer address).');
            console.log(`Content: Address text is "${await contactInfo.getText()}"`);

        } catch (e) {
            console.log('FAILED: XPath 2 failed.');
        }

          try {

            let partialLink = await driver.findElement(By.partialLinkText('Факультеты'));
            console.log('SUCCESS: Element found by Partial Link Text ("Факультеты").');
            console.log(`Content: Full text found is "${await partialLink.getText()}"`);

        } catch (e) {
            console.log('FAILED: Partial Link Text search failed.');
        }

        try {

            let mainNavLinks = await driver.findElements(By.css('.top-menu > li > a'));
            console.log(`SUCCESS: Found ${mainNavLinks.length} navigation links.`);

            console.log('Listing found elements:');

            for (let link of mainNavLinks) {
                let linkText = await link.getText();
                if (linkText) {
                    console.log(` - Navigation Item: ${linkText}`);
                }

            }

        } catch (e) {
            console.log('FAILED: Finding multiple elements failed.');
        }

    }
    catch (err) {
        console.error(err);
    }
    finally{
        console.log('--- Tests Completed. Closing browser... ---');
        await driver.quit();
    }
}


runBelstuTest();