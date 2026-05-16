from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


class LoginPage:
    """Handles all interactions on the Login page."""
    def __init__(self, driver):
        self.driver = driver
        self.url = "https://www.saucedemo.com/"
        
        # Locators
        self.USERNAME_FIELD = (By.ID, "user-name")
        self.PASSWORD_FIELD = (By.ID, "password")
        self.LOGIN_BUTTON = (By.ID, "login-button")

    def open(self):
        self.driver.get(self.url)

    def login(self, username, password):
        self.driver.find_element(*self.USERNAME_FIELD).send_keys(username)
        self.driver.find_element(*self.PASSWORD_FIELD).send_keys(password)
        self.driver.find_element(*self.LOGIN_BUTTON).click()

class InventoryPage:
    """Handles all interactions on the Products/Inventory page."""
    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(self.driver, 10)
        
        # Locators
        self.TITLE = (By.CLASS_NAME, "title")
        self.INVENTORY_ITEMS = (By.CLASS_NAME, "inventory_item_name")
        self.CART_BADGE = (By.CLASS_NAME, "shopping_cart_badge")
        self.ADD_TO_CART_BTN = (By.ID, "add-to-cart-sauce-labs-backpack")

    def get_title(self):
        return self.wait.until(EC.visibility_of_element_located(self.TITLE)).text

    def get_all_product_names(self):
        items = self.driver.find_elements(*self.INVENTORY_ITEMS)
        return [item.text for item in items]

    def add_backpack_to_cart(self):
        self.driver.find_element(*self.ADD_TO_CART_BTN).click()

    def get_cart_count(self):
        return self.driver.find_element(*self.CART_BADGE).text


def run_sauce_demo_test():
  
    options = Options()
    driver = webdriver.Firefox(options=options)
    
    print("\n--- Starting SauceDemo POM Test ---")
    
    try:
        login_page = LoginPage(driver)
        login_page.open()
        print("Logging in...")
        login_page.login("standard_user", "secret_sauce")

        
        inventory_page = InventoryPage(driver)
        
        
        title = inventory_page.get_title()
        print(f"Page Title: {title}")
        
        products = inventory_page.get_all_product_names()
        print(f"Found {len(products)} products.")
        print(f"First product: {products[0]}")

        print("Adding Backpack to cart...")
        inventory_page.add_backpack_to_cart()
        
        count = inventory_page.get_cart_count()
        print(f"Items in cart: {count}")

        if count == "1":
            print("SUCCESS: POM Test Passed!")
        else:
            print("FAILED: Cart count mismatch.")

    except Exception as e:
        print(f"ERROR: {e}")
    finally:
        print("Closing browser...")
        driver.quit()

if __name__ == "__main__":
    run_sauce_demo_test()