const { Builder, Browser, By, Key, until } = require('selenium-webdriver');

const TEST_EMAIL    = 'philmade6@gmail.com';
const TEST_PASSWORD = 'Todoist!TestPass1';
const LOGIN_URL     = 'https://todoist.com/auth/login';
const APP_URL       = 'https://app.todoist.com/app';

function assertResult(testName, actual, expected) {
    if (actual === expected) {
        console.log(`PASSED: ${testName}`);
        console.log(`Expected: "${expected}"`);
        console.log(`Actual: "${actual}"`);
    } else {
        console.log(`FAILED: ${testName}`);
        console.log(`Expected: "${expected}"`);
        console.log(`Actual: "${actual}"`);
    }
}

function assertContains(testName, actual, expectedSubstring) {
    if (actual.includes(expectedSubstring)) {
        console.log(`PASSED: ${testName}`);
        console.log(`Result contains: "${expectedSubstring}"`);
    } else {
        console.log(`FAILED: ${testName}`);
        console.log(`Expected "${actual}" to contain "${expectedSubstring}"`);
    }
}

function assertTrue(testName, condition, description) {
    if (condition) {
        console.log(`PASSED: ${testName} - ${description}`);
    } else {
        console.log(`FAILED: ${testName} - ${description}`);
    }
}

async function waitForAppLoad(driver, timeout = 25000) {
    await driver.wait(async () => {
        let url = await driver.getCurrentUrl();
        return url.includes('/app') && !url.includes('/auth');
    }, timeout, 'App URL did not resolve');

    await driver.wait(async () => {
        let spinners = await driver.findElements(By.css('.loading_screen'));
        if (spinners.length === 0) return true;
        for (let s of spinners) {
            try {
                if (await s.isDisplayed()) return false;
            } catch (e) { return true; }
        }
        return true;
    }, timeout, 'Loading screen did not disappear');

    await driver.sleep(4000);
}


async function testAuthorization(driver) {
    console.log('\n========================================');
    console.log('TEST 1: Authorization on todoist.com');
    console.log('========================================');

    try {
        await driver.get(LOGIN_URL);

        await driver.manage().setTimeouts({ implicit: 5000 });

        await driver.sleep(2000);

        // Step 1: Enter email
        let emailField = await driver.wait(
            until.elementLocated(By.css('input[type="email"]')),
            10000,
            'Email field not found within 10 seconds'
        );
        await driver.wait(until.elementIsVisible(emailField), 5000);
        await emailField.clear();
        await emailField.sendKeys(TEST_EMAIL);
        console.log('  -> Email entered');

        // Step 2: Click "Log in" / "Continue" to proceed to password step
        let continueButton = await driver.findElement(
            By.css('button[type="submit"]')
        );
        await continueButton.click();
        console.log('  -> Continue button clicked');

        // Step 3: Wait for password field to appear (two-step login)
        await driver.sleep(2000);
        let passwordField = await driver.wait(
            until.elementLocated(By.css('input[type="password"]')),
            10000,
            'Password field not found'
        );
        await driver.wait(until.elementIsVisible(passwordField), 5000);
        await passwordField.clear();
        await passwordField.sendKeys(TEST_PASSWORD);
        console.log('  -> Password entered');

        // Step 4: Click the login button (find it fresh after password field loaded)
        await driver.sleep(500);
        let buttons = await driver.findElements(By.css('button[type="submit"]'));
        let loginButton = null;
        for (let btn of buttons) {
            try {
                if (await btn.isDisplayed()) { loginButton = btn; break; }
            } catch (e) {}
        }
        if (!loginButton) throw new Error('No visible submit button found');
        await loginButton.click();
        console.log('  -> Login button clicked');

        // Wait for redirect to app
        await driver.wait(async () => {
            let url = await driver.getCurrentUrl();
            return url.includes('/app') && !url.includes('/auth');
        }, 20000, 'Did not redirect to app after login');

        await waitForAppLoad(driver);

        let currentUrl = await driver.getCurrentUrl();
        assertContains(
            'Authorization - redirect to main page',
            currentUrl,
            '/app'
        );

        // Try to find any interactive element in the sidebar/header as proof of login
        let appElement = await driver.wait(
            until.elementLocated(By.css(
                '[data-testid],' +
                'nav,' +
                'aside,' +
                '[role="navigation"],' +
                '[role="banner"],' +
                'header'
            )),
            15000,
            'No app elements found after login'
        );
        let isDisplayed = await appElement.isDisplayed();
        assertTrue(
            'Authorization - app interface loaded',
            isDisplayed,
            'App UI element is visible on the page'
        );

    } catch (err) {
        console.log(`ERROR in authorization test: ${err.message}`);
    }
}

async function testCreateProject(driver) {
    console.log('\n========================================');
    console.log('TEST 2 (Test Case 1): Create a new project');
    console.log('========================================');

    const PROJECT_NAME = 'Test Project ' + Date.now();

    try {
        await driver.get(APP_URL);
        await driver.manage().setTimeouts({ implicit: 5000 });

        await waitForAppLoad(driver);

        // Find the add project button using various possible selectors
        let addProjectBtn = await driver.wait(
            until.elementLocated(By.css(
                '[data-testid="add-project-button"],' +
                'button[aria-label*="Add project"],' +
                'button[aria-label*="add project"],' +
                'a[aria-label*="Add project"]'
            )),
            15000,
            'Add project button not found'
        );
        await addProjectBtn.click();
        console.log('  -> "Add project" button clicked');

        let projectNameInput = await driver.wait(
            until.elementLocated(By.css(
                'input[placeholder*="Name"],' +
                'input[placeholder*="name"],' +
                '#edit_project_modal_field_name,' +
                '[data-testid="project-name-input"] input,' +
                'input[aria-label*="project"],' +
                'input[aria-label*="Project"]'
            )),
            10000,
            'Project name input field did not appear'
        );
        await projectNameInput.clear();
        await projectNameInput.sendKeys(PROJECT_NAME);
        console.log(`  -> Project name entered: "${PROJECT_NAME}"`);

        let submitBtn = await driver.findElement(
            By.css('button[type="submit"]')
        );
        await submitBtn.click();
        console.log('  -> Project created');

        await driver.sleep(3000);

        let pageTitle = await driver.wait(
            until.elementLocated(
                By.xpath("//*[contains(text(),'" + PROJECT_NAME.substring(0, 12) + "')]")
            ),
            10000,
            'Project title not found on the page'
        );
        let titleText = await pageTitle.getText();
        assertContains(
            'Create project - project is displayed on the page',
            titleText,
            'Test Project'
        );

    } catch (err) {
        console.log(`ERROR in create project test: ${err.message}`);
    }
}

async function testCreateTask(driver) {
    console.log('\n========================================');
    console.log('TEST 3 (Test Case 2): Add a new task');
    console.log('========================================');

    const TASK_NAME = 'Test Task ' + Date.now();

    try {
        await driver.get(APP_URL + '/today');
        await driver.manage().setTimeouts({ implicit: 5000 });

        await waitForAppLoad(driver);

        let addTaskBtn = await driver.wait(
            until.elementLocated(By.css(
                '[data-testid="quick-add-task-button"],' +
                'button[aria-label*="Add task"],' +
                'button[aria-label*="add task"],' +
                'button[class*="plus_add"]'
            )),
            15000,
            'Add task button not found'
        );
        await addTaskBtn.click();
        console.log('  -> "Add task" button clicked');

        let taskInput = await driver.wait(
            until.elementLocated(By.css(
                '[role="textbox"][contenteditable="true"],' +
                'p[data-placeholder],' +
                '.task_editor__content_field [contenteditable="true"],' +
                '[data-testid="task-name-input"]'
            )),
            10000,
            'Task input field did not appear'
        );
        await taskInput.click();
        await taskInput.sendKeys(TASK_NAME);
        console.log(`  -> Task name entered: "${TASK_NAME}"`);

        let submitTaskBtn = await driver.findElement(By.css(
            '[data-testid="task-editor-submit-button"],' +
            'button[type="submit"]'
        ));
        await submitTaskBtn.click();
        console.log('  -> Task added');

        await driver.sleep(3000);

        let taskElement = await driver.wait(
            until.elementLocated(
                By.xpath("//*[contains(text(),'" + TASK_NAME.substring(0, 9) + "')]")
            ),
            10000,
            'Added task not found in the list'
        );
        let taskText = await taskElement.getText();
        assertContains(
            'Add task - task is displayed in the list',
            taskText,
            'Test Task'
        );

    } catch (err) {
        console.log(`ERROR in add task test: ${err.message}`);
    }
}

async function testEndToEndScenario(driver) {
    console.log('\n========================================');
    console.log('TEST 4: End-to-End Testing (E2E)');
    console.log('Scenario: Create Project -> Add Task -> Complete Task');
    console.log('========================================');

    const E2E_PROJECT = 'E2E Project ' + Date.now();
    const E2E_TASK    = 'E2E Task ' + Date.now();

    try {
        console.log('\n  --- Step 1: Create project ---');
        await driver.get(APP_URL);
        await driver.manage().setTimeouts({ implicit: 5000 });

        await waitForAppLoad(driver);

        let addProjBtn = await driver.wait(
            until.elementLocated(By.css(
                '[data-testid="add-project-button"],' +
                'button[aria-label*="Add project"],' +
                'button[aria-label*="add project"],' +
                'a[aria-label*="Add project"]'
            )),
            15000
        );
        await addProjBtn.click();

        let projInput = await driver.wait(
            until.elementLocated(By.css(
                'input[placeholder*="Name"],' +
                'input[placeholder*="name"],' +
                '#edit_project_modal_field_name,' +
                'input[aria-label*="project"],' +
                'input[aria-label*="Project"]'
            )),
            10000
        );
        await projInput.clear();
        await projInput.sendKeys(E2E_PROJECT);

        let addBtn = await driver.findElement(
            By.css('button[type="submit"]')
        );
        await addBtn.click();
        console.log(`  -> Project "${E2E_PROJECT}" created`);

        await driver.sleep(3000);

        let projHeader = await driver.wait(
            until.elementLocated(
                By.xpath("//*[contains(text(),'" + E2E_PROJECT.substring(0, 11) + "')]")
            ),
            10000
        );
        let projText = await projHeader.getText();
        assertContains('E2E Step 1 - Project created', projText, 'E2E Project');

        console.log('\n  --- Step 2: Add task to project ---');

        let addTaskBtn = await driver.wait(
            until.elementLocated(By.css(
                '[data-testid="quick-add-task-button"],' +
                'button[aria-label*="Add task"],' +
                'button[aria-label*="add task"],' +
                'button[class*="plus_add"]'
            )),
            15000
        );
        await addTaskBtn.click();

        let taskInput = await driver.wait(
            until.elementLocated(By.css(
                '[role="textbox"][contenteditable="true"],' +
                'p[data-placeholder],' +
                '.task_editor__content_field [contenteditable="true"],' +
                '[data-testid="task-name-input"]'
            )),
            10000
        );
        await taskInput.click();
        await taskInput.sendKeys(E2E_TASK);

        let submitTask = await driver.findElement(By.css(
            '[data-testid="task-editor-submit-button"],' +
            'button[type="submit"]'
        ));
        await submitTask.click();
        console.log(`  -> Task "${E2E_TASK}" added to project`);

        await driver.sleep(3000);

        let taskElem = await driver.wait(
            until.elementLocated(
                By.xpath("//*[contains(text(),'" + E2E_TASK.substring(0, 8) + "')]")
            ),
            10000
        );
        let taskDisplayed = await taskElem.isDisplayed();
        assertTrue('E2E Step 2 - Task added to project', taskDisplayed,
                    'Task is visible on the project page');

        console.log('\n  --- Step 3: Complete task ---');

        let checkbox = await driver.findElement(By.css(
            'button[role="checkbox"],' +
            'button[aria-label*="Complete"],' +
            '[data-testid="checkbox"],' +
            'input[type="checkbox"]'
        ));
        await checkbox.click();
        console.log('  -> Task marked as completed');

        await driver.sleep(3000);

        let remainingTasks = await driver.findElements(
            By.xpath("//*[contains(text(),'" + E2E_TASK.substring(0, 8) + "')]")
        );
        assertTrue(
            'E2E Step 3 - Task completed and removed from list',
            remainingTasks.length === 0,
            'Completed task is no longer displayed in the active list'
        );

        console.log('\n  End-to-end scenario completed successfully!');

    } catch (err) {
        console.log(`ERROR in E2E scenario: ${err.message}`);
    }
}

async function testCheckboxAndRadio(driver) {
    console.log('\n========================================');
    console.log('TEST 5: Checkbox and Radio Button (demoqa.com)');
    console.log('========================================');

    try {
        console.log('\n  --- Part A: Checkbox ---');
        await driver.get('https://demoqa.com/checkbox');

        await driver.manage().setTimeouts({ implicit: 5000 });

        let expandBtn = await driver.wait(
            until.elementLocated(
                By.css('button[title="Toggle"]')
            ),
            10000,
            'Checkbox tree toggle button not found'
        );
        await expandBtn.click();
        console.log('  -> Checkbox tree expanded');

        await driver.sleep(1000);

        let desktopCheckbox = await driver.findElement(
            By.css('ol.rct-tree ol li:first-child span.rct-checkbox')
        );
        await desktopCheckbox.click();
        console.log('  -> "Desktop" checkbox checked');

        let resultArea = await driver.wait(
            until.elementLocated(By.id('result')),
            5000,
            'Result area not found'
        );
        let resultText = await resultArea.getText();
        assertContains(
            'Checkbox - result contains "desktop"',
            resultText.toLowerCase(),
            'desktop'
        );

        let documentsCheckbox = await driver.findElement(
            By.xpath("//span[contains(@class,'rct-title') and text()='Documents']/preceding-sibling::span[contains(@class,'rct-checkbox')]")
        );
        await documentsCheckbox.click();
        console.log('  -> "Documents" checkbox checked');

        resultText = await resultArea.getText();
        assertContains(
            'Checkbox - result contains "documents"',
            resultText.toLowerCase(),
            'documents'
        );

        console.log('\n  --- Part B: Radio Button ---');
        await driver.get('https://demoqa.com/radio-button');

        await driver.wait(
            until.elementLocated(By.css('.custom-control.custom-radio')),
            10000,
            'Radio buttons did not load'
        );

        let yesRadio = await driver.findElement(
            By.css('label[for="yesRadio"]')
        );
        await yesRadio.click();
        console.log('  -> "Yes" radio button selected');

        let radioResult = await driver.wait(
            until.elementLocated(By.css('span.text-success')),
            5000,
            'Radio button selection result not found'
        );
        let radioText = await radioResult.getText();
        assertResult('Radio Button - selected "Yes"', radioText, 'Yes');

        let impressiveRadio = await driver.findElement(
            By.xpath("//div[contains(@class,'custom-radio')]//label[@for='impressiveRadio']")
        );
        await impressiveRadio.click();
        console.log('  -> "Impressive" radio button selected');

        radioResult = await driver.findElement(By.css('span.text-success'));
        radioText = await radioResult.getText();
        assertResult('Radio Button - selected "Impressive"', radioText, 'Impressive');

        let noRadio = await driver.findElement(By.id('noRadio'));
        let isDisabled = !(await noRadio.isEnabled());
        assertTrue(
            'Radio Button - "No" button is disabled',
            isDisabled,
            'Radio button "No" is inactive (disabled)'
        );

    } catch (err) {
        console.log(`ERROR in checkbox/radio test: ${err.message}`);
    }
}

async function runAllTests() {
    console.log('========================================');
    console.log('  Lab 7 - Task 2');
    console.log('  UI Test Automation');
    console.log('  Topic: Project Management System (Todoist)');
    console.log('  Selenium + JavaScript');
    console.log('========================================');

    let driver = await new Builder().forBrowser(Browser.FIREFOX).build();

    try {
        await driver.manage().window().maximize();

        await testAuthorization(driver);

        await testCreateProject(driver);

        await testCreateTask(driver);

        await testEndToEndScenario(driver);

        await testCheckboxAndRadio(driver);

    } catch (err) {
        console.error('Critical error:', err.message);
    } finally {
        console.log('\n========================================');
        console.log('All tests completed. Closing browser...');
        console.log('========================================');
        await driver.quit();
    }
}

runAllTests();
