import React, { Component } from 'react';
import logo from '../logo.png';
import Web3 from 'web3';
import './App.css';
import Marketplace from '../abis/Marketplace.json';

class App extends Component {

  async componentWillMount(){
    await this.loadWeb3()
    //await this.loadBlockchainData()
  }
  async loadWeb3(){

        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
            await window.ethereum.enable();
        }
        else if (window.web3) {
            window.web3 = new Web3(window.web3.currentProvider);
        }
        // Non-dapp browsers...
        else {
            console.log('Non-Ethereum browser detected. You should consider trying MetaMask!');
        }
  }

constructor(props){

  super(props)
  this.state={

    account1: ''
}
}
  async loadBlockchainData(){

    //load Acccounts
    const web3=window.web3
    const abis =Marketplace.abis
    const address=Marketplace.networks[5777].address
    const allaccount =await web3.eth.getAccounts()
    console.log(allaccount)
    const marketplace=web3.eth.Contract(abis,address)
    console.log(marketplace)
    this.setState({ account1: allaccount[0] })

  }
  render() {
    return (
      <div>
        <nav className="navbar navbar-dark fixed-top bg-dark flex-md-nowrap p-0 shadow">
          <a
            className="navbar-brand col-sm-3 col-md-2 mr-0"
            href="http://www.dappuniversity.com/bootcamp"
            target="_blank"
            rel="noopener noreferrer"
          >
            Dapp University
          </a>
        </nav>
        <div className="container-fluid mt-5">
          <div className="row">
            <main role="main" className="col-lg-12 d-flex text-center">
              <div className="content mr-auto ml-auto">
                <a
                  href="http://www.dappuniversity.com/bootcamp"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <img src={logo} className="App-logo" alt="logo" />
                </a>
                <h1>Dapp University Starter Kit</h1>
                <p>Account --> {this.state.account1}</p>
                <p>
                  Edit <code>src/components/App.js</code> and save to reload.
                </p>

                <a
                  className="App-link"
                  href="http://www.dappuniversity.com/bootcamp"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  LEARN BLOCKCHAIN <u><b>NOW! </b></u>
                </a>
              </div>
            </main>
          </div>
        </div>
      </div>
    );
  }
}

export default App;
