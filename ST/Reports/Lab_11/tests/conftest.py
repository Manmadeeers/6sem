from pathlib import Path

import pytest
from selenium import webdriver


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PAGE_URL = PROJECT_ROOT.joinpath("index.html").as_uri()


@pytest.fixture
def driver():
    options = webdriver.ChromeOptions()
    options.add_argument("--headless=new")
    options.add_argument("--window-size=1280,900")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    browser = webdriver.Chrome(options=options)
    yield browser
    browser.quit()


@pytest.fixture
def open_form_page(driver):
    driver.get(PAGE_URL)
    return driver
