import undetected_chromedriver as uc
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait
import ddddocr
import time
import logging
import traceback
import subprocess
import re
import sys
from const import *


class DataFetcher:

    def __init__(self, username: str, password: str):

        self._username = username
        self._password = password
        self._ocr = ddddocr.DdddOcr(show_ad = False)
        self._chromium_version = self._get_chromium_version()

    
    def fetch(self):
        '''the entry, only retry logic here '''
        for retry_times in range(1, RETRY_TIMES_LIMIT + 1):
            try:
                return self._fetch()
            except Exception as e:
                if(retry_times == RETRY_TIMES_LIMIT):
                    raise e
                traceback.print_exc()
                logging.error(f"Webdriver quit abnormly, reason: {e}. {RETRY_TIMES_LIMIT - retry_times} retry times left.")
                wait_time = retry_times * RETRY_WAIT_TIME_OFFSET_UNIT
                time.sleep(wait_time)
                
            
    
    def _fetch(self):
        '''main logic here'''

        driver = self._get_webdriver()
        logging.info("Webdriver initialized.")
        try:
            self._login(driver)
            logging.info(f"Login successfully on {LOGIN_URL}" )

            user_id_list = self._get_user_ids(driver)
            logging.info(f"get all user id: {user_id_list}")

            balance_list = self._get_electric_balances(driver, user_id_list)
            ### get data except electricity charge balance
            last_daily_usage_list, yearly_charge_list, yearly_usage_list = self._get_other_data(driver, user_id_list)

            driver.quit()

            logging.info("Webdriver quit after fetching data successfully.")

            return user_id_list, balance_list, last_daily_usage_list, yearly_charge_list, yearly_usage_list

        finally:
                driver.quit()

    def _get_webdriver(self):
        chrome_options = Options()
        chrome_options.add_argument('--incognito')
        chrome_options.add_argument('--window-size=4000,1600')
        chrome_options.add_argument('--headless')
        chrome_options.add_argument('--no-sandbox')
        chrome_options.add_argument('--disable-gpu')
        chrome_options.add_argument('--disable-dev-shm-usage')
        driver = uc.Chrome(driver_executable_path = "/usr/bin/chromedriver" ,options = chrome_options, version_main = self._chromium_version)
        driver.implicitly_wait(DRIVER_IMPLICITY_WAIT_TIME)
        return driver

    def _login(self, driver):

        driver.get(LOGIN_URL)

        # swtich to username-password login page
        driver.find_element(By.CLASS_NAME,"user").click()

        # input username and password
        input_elements = driver.find_elements(By.CLASS_NAME,"el-input__inner")
        input_elements[0].send_keys(self._username)
        input_elements[1].send_keys(self._password)
        
        captcha_element = driver.find_element(By.CLASS_NAME,"code-mask")
        
        # sometimes ddddOCR may fail, so add retry logic)
        for retry_times in range(1, RETRY_TIMES_LIMIT + 1):

            img_src = captcha_element.find_element(By.TAG_NAME,"img").get_attribute("src")
            img_base64 = img_src.replace("data:image/jpg;base64,","")
            orc_result = str(self._ocr.classification(ddddocr.base64_to_image(img_base64)))

            if(not self._is_captcha_legal(orc_result)):
                logging.debug(f"The captcha is illegal, which is caused by ddddocr, {RETRY_TIMES_LIMIT - retry_times} retry times left.")
                WebDriverWait(driver, DRIVER_IMPLICITY_WAIT_TIME).until(EC.element_to_be_clickable(captcha_element))
                driver.execute_script("arguments[0].click();", captcha_element)
                time.sleep(2)
                continue

            input_elements[2].send_keys(orc_result)
            
            # click login button
            self._click_button(driver, By.CLASS_NAME, "el-button.el-button--primary")
            try:
                return WebDriverWait(driver,LOGIN_EXPECTED_TIME).until(EC.url_changes(LOGIN_URL))
            except:
                logging.debug(f"Login failed, maybe caused by invalid captcha, {RETRY_TIMES_LIMIT - retry_times} retry times left.")

        raise Exception("Login failed, maybe caused by 1.incorrect phone_number and password, please double check. or 2. network, please mnodify LOGIN_EXPECTED_TIME in const.py and rebuild.")

    def _get_electric_balances(self, driver, user_id_list):

        balance_list = []

        # switch to electricity charge balance page
        driver.get(BALANCE_URL)

        # get electricity charge balance for each user id
        for i in range(1, len(user_id_list) + 1):
            balance = self._get_eletric_balance(driver)
            if(balance is None):
                logging.info(f"Get electricity charge balance for {user_id_list[i-1]} failed, Pass.")
            else:
                logging.info(f"Get electricity charge balance for {user_id_list[i-1]} successfully, balance is {balance} CNY.")
            balance_list.append(balance)
            
            # swtich to next userid
            if(i != len(user_id_list)):
                self._click_button(driver, By.CLASS_NAME, "el-input__inner")
                self._click_button(driver, By.XPATH, f"//ul[@class='el-scrollbar__view el-select-dropdown__list']/li[{i + 1}]")

        return balance_list
    
    def _get_other_data(self, driver, user_id_list):

        last_daily_usage_list =[]
        yearly_usage_list = []
        yearly_charge_list = []

        # swithc to electricity usage page
        driver.get(ELECTRIC_USAGE_URL)

        # get data for each user id
        for i in range(1, len(user_id_list) + 1):

            yearly_usage, yearly_charge = self._get_yearly_data(driver)

            if(yearly_usage is None):
                logging.error(f"Get year power usage for {user_id_list[i-1]} failed, pass")
            else:
                logging.info(f"Get year power usage for {user_id_list[i-1]} successfully, usage is {yearly_usage} kwh")
            if(yearly_charge is None):
                logging.error(f"Get year power charge for {user_id_list[i-1]} failed, pass")
            else:
                logging.info(f"Get year power charge for {user_id_list[i-1]} successfully, yealrly charge is {yearly_charge} CNY")

            last_daily_usage = self._get_yesterday_usage(driver)

            if(last_daily_usage is None):
                logging.error(f"Get daily power consumption for {user_id_list[i-1]} failed, pass")
            else:
                logging.info(f"Get daily power consumption for {user_id_list[i-1]} successfully, usage is {last_daily_usage} kwh.")

            last_daily_usage_list.append(last_daily_usage)
            yearly_charge_list.append(yearly_charge)
            yearly_usage_list.append(yearly_usage)

            # switch to next user id
            if(i != len(user_id_list)):
                self._click_button(driver, By.CLASS_NAME, "el-input.el-input--suffix")
                self._click_button(driver, By.XPATH, f"//body/div[@class='el-select-dropdown el-popper']//ul[@class='el-scrollbar__view el-select-dropdown__list']/li[{i + 1}]")
            
        return last_daily_usage_list, yearly_charge_list, yearly_usage_list

    def _get_user_ids(self, driver):

        # click roll down button for user id
        self._click_button(driver, By.XPATH, "//div[@class='el-dropdown']/span")
        # wait for roll down menu displayed
        target = driver.find_element(By.CLASS_NAME, "el-dropdown-menu.el-popper").find_element(By.TAG_NAME, "li")
        WebDriverWait(driver, DRIVER_IMPLICITY_WAIT_TIME).until(EC.visibility_of(target))
        WebDriverWait(driver, DRIVER_IMPLICITY_WAIT_TIME).until(EC.text_to_be_present_in_element((By.XPATH, "//ul[@class='el-dropdown-menu el-popper']/li"), ":"))

        # get user id one by one
        userid_elements = driver.find_element(By.CLASS_NAME, "el-dropdown-menu.el-popper").find_elements(By.TAG_NAME, "li")
        userid_list = []
        for element in userid_elements:
            userid_list.append(re.findall("[0-9]+", element.text)[-1])
        return userid_list

    def _get_eletric_balance(self, driver):
        try:
            balance = driver.find_element(By.CLASS_NAME,"num").text
            return float(balance)
        except:
            return None
            
    
    def _get_yearly_data(self, driver):

        try:    
            self._click_button(driver, By.XPATH, "//div[@class='el-tabs__nav is-top']/div[@id='tab-first']")

        # wait for data displayed
            target = driver.find_element(By.CLASS_NAME, "total")
            WebDriverWait(driver, DRIVER_IMPLICITY_WAIT_TIME).until(EC.visibility_of(target))
        except:
            return None, None

        # get data
        try:
            yearly_usage = driver.find_element(By.XPATH, "//ul[@class='total']/li[1]/span").text

        except:
            yearly_usage = None

        try:
            yearly_charge = driver.find_element(By.XPATH, "//ul[@class='total']/li[2]/span").text
        except:
            yearly_charge = None
            
        return yearly_usage, yearly_charge

        

    def _get_yesterday_usage(self, driver):
        try:
            self._click_button(driver, By.XPATH,"//div[@class='el-tabs__nav is-top']/div[@id='tab-second']")
        # wait for data displayed
            usage_element = driver.find_element(By.XPATH,"//div[@class='el-tab-pane dayd']//div[@class='el-table__body-wrapper is-scrolling-none']/table/tbody/tr[1]/td[2]/div")
            WebDriverWait(driver, DRIVER_IMPLICITY_WAIT_TIME). until(EC.visibility_of(usage_element))
            return(float(usage_element.text))
        except:
            return None

    @staticmethod
    def _click_button(driver, button_search_type, button_search_key):
        '''wrapped click function, click only when the element is clickable'''
        click_element = driver.find_element(button_search_type, button_search_key)
        WebDriverWait(driver, DRIVER_IMPLICITY_WAIT_TIME).until(EC.element_to_be_clickable(click_element))
        driver.execute_script("arguments[0].click();", click_element)

    @staticmethod
    def _is_captcha_legal(captcha):
        ''' check the ddddocr result, justify whether it's legal'''
        if(len(captcha) != 4): 
            return False
        for s in captcha:
            if(not s.isalpha() and not s.isdigit()):
                return False
        return True
    
    @staticmethod
    def _get_chromium_version():
        result = str(subprocess.check_output(["chromium", "--product-version"]))
        return re.findall(r"(\d*)\.",result)[0]

if(__name__ == "__main__"):
    '''You can test it in the docker container. Replace the following params and use 'python3 data_fetcher.py' '''

    logger = logging.getLogger()
    logger.setLevel("INFO")
    logging.getLogger("urllib3").setLevel(logging.CRITICAL)
    format = logging.Formatter("%(asctime)s  [%(levelname)-8s] ---- %(message)s","%Y-%m-%d %H:%M:%S")
    sh = logging.StreamHandler(stream=sys.stdout) 
    sh.setFormatter(format)
    logger.addHandler(sh)
    
    fetcher = DataFetcher("CHNAGE_ME_PHONE_NUMBER","CHANGE_ME_PASSWORD")
    print(fetcher.fetch())
