define([
    'backbone',
    'marionette',
    'underscore',
    'highcharts',
    'hbs!app/applets/stackedGraph/list/stackedGraphViewTemplate',
    'app/applets/stackedGraph/list/chartsCompositeView',
    'app/applets/stackedGraph/utils/utils',
    'app/applets/lab_results_grid/applet',
    'app/applets/vitals/applet',
    'typeahead',
    'highcharts-more'
], function(Backbone, Marionette, _, Highcharts, StackedGraphViewTemplate, ChartsCompositeView, Utils) {


    // var FilterView = Backbone.Marionette.ItemView.extend({
    //     template: _.template("I am a filter view!")
    // });

    return Backbone.Marionette.LayoutView.extend({
        template: StackedGraphViewTemplate,
        initialize: function(options) {
            var self = this;
            this.predefined = ADK.ADKApp.currentScreen.config.predefined;
            this.allReadyAdded = [];
            this.activeCharts = [];
            this.timeLineCharts = [];
            this.instanceId = options.appletConfig.instanceId;
            this.chartOptionsCollection = new Backbone.Collection();
            this.chartOptionsCollection.on('remove', function(model, collection, options) {
                self.activeCharts.splice(options.index, 1);
                var index = _.indexOf(self.allReadyAdded, model.get('typeName').toUpperCase());
                if (index !== -1) {
                    self.allReadyAdded.splice(index, 1);
                }
                if(collection.length === 0){
                    self.chartsCompositeView.$noGraph.show();
                }
            });
            // this.filterView = new FilterView();
            this.chartsCompositeView = new ChartsCompositeView({
                collection: this.chartOptionsCollection,
                instanceId: this.instanceId,
                options: {
                    appletId: options.appletConfig.id,
                    allReadyAdded: self.allReadyAdded
                },
                activeCharts: this.activeCharts,
                timeLineCharts: this.timeLineCharts
            });
            var readyToChart = true;
            this.stackedGraphChannel = ADK.Messaging.getChannel('stackedGraph');
            this.stackedGraphChannel.on('readyToChart', function(response) {
                if (response.response.requesterInstanceId === self.instanceId) {
                    self.chartsCompositeView.$noGraph.hide();
                    self.chartOptionsCollection.unshift(response.response);
                    self.allReadyAdded.unshift(response.response.typeName);
                    readyToChart = true;
                }
            });

            this.listenTo(ADK.Messaging, 'globalDate:selected', function(dateModel) {
                var sessionGlobalDate = ADK.SessionStorage.getModel_SessionStoragePreference('globalDate');
                var fromDate = moment(sessionGlobalDate.get('fromDate'), 'MM/DD/YYYY');
                var toDate = moment(sessionGlobalDate.get('toDate'), 'MM/DD/YYYY');

                //add 1 day to toDate to enusure red line for current date is always displayed on the chart
                toDate.add(1,'d');
                _.each(this.activeCharts, function(e, i) {
                    e.xAxis[0].setExtremes(Date.UTC(fromDate.year(), fromDate.month(), fromDate.date()), Date.UTC(toDate.year(), toDate.month(), toDate.date()));
                });

                _.each(self.timeLineCharts, function(e, i) {
                    e.xAxis[0].setExtremes(Date.UTC(fromDate.year(), fromDate.month(), fromDate.date()), Date.UTC(toDate.year(), toDate.month(), toDate.date()));
                });
            });

            this.stackedGraphChannel.on('delete', function(response) {

                if (response.model.attributes.requesterInstanceId !== self.instanceId || this.predefined === 'true') {
                    return;
                }

                var pickListPersistanceFetchOptions = {
                    resourceTitle: 'user-defined-stack',
                    fetchType: 'DELETE',
                    criteria: {
                        id: ADK.ADKApp.currentScreen.config.id,
                        instanceId: self.instanceId,
                        graphType: response.model.attributes.graphType,
                        typeName: response.model.attributes.typeName.toUpperCase()
                    },

                    onSuccess: function() {
                        self.chartOptionsCollection.remove(response.model);

                    }
                };

                ADK.ResourceService.fetchCollection(pickListPersistanceFetchOptions);

            });

            var pickListPersistanceFetchOptions = {
                resourceTitle: 'user-defined-stack',
                fetchType: 'GET',
                criteria: {
                    id: ADK.ADKApp.currentScreen.config.id,
                    predefined: this.predefined
                }
            };

            pickListPersistanceFetchOptions.onSuccess = function(pickListCollection) {
                var persistedPickList;
                if (pickListCollection.models.length > 0 && pickListCollection.models[0].attributes.userdefinedgraphs !== undefined) {
                    var applet = _.find(pickListCollection.models[0].attributes.userdefinedgraphs.applets, function(applet) {
                        return applet.instanceId === self.instanceId;
                    });

                    if (applet !== undefined) {
                        persistedPickList = applet.graphs;
                    }
                }

                if (persistedPickList !== undefined) {
                    var ind = 0;
                    var interval = setInterval(function() {
                        if (persistedPickList.length === ind) {
                            clearInterval(interval);

                        } else {
                            if (readyToChart) {
                                readyToChart = false;
                                var persistedPickListItem = persistedPickList[ind];
                                var params = {
                                    typeName: persistedPickListItem.typeName,
                                    instanceId: self.instanceId,
                                    graphType: persistedPickListItem.graphType

                                };
                                var channel;
                                if (persistedPickListItem.graphType === 'Vitals') {
                                    channel = ADK.Messaging.getChannel('vitals');

                                } else if (persistedPickListItem.graphType === 'Lab Tests') {
                                    channel = ADK.Messaging.getChannel('lab_results_grid');
                                }

                                channel.request('chartInfo', params);
                                ind = ind + 1;
                            }
                        }

                    }, 100);
                }
            };

            ADK.ResourceService.fetchCollection(pickListPersistanceFetchOptions);
            //end of intialize
        },
        onShow: function() {
            var self = this;

            var sessionGlobalDate = ADK.SessionStorage.getModel_SessionStoragePreference('globalDate');
            var fromDate = moment(sessionGlobalDate.get('fromDate'), 'MM/DD/YYYY');
            var toDate = moment(sessionGlobalDate.get('toDate'), 'MM/DD/YYYY');

            //add 1 day to toDate to enusure red line for current date is always displayed on the chart
            toDate.add(1, 'd');

            var interval1 = setInterval(function() {
                if (self.$('.placeholder').length > 0) {
                    clearInterval(interval1);
                    var timeLineChart1 = self.$('.placeholder').highcharts($.extend(true, {}, self.pChartOptions, {
                        xAxis: {
                            labels: {
                                y: -10
                            }
                        }
                    })).highcharts();
                    timeLineChart1.xAxis[0].setExtremes(Date.UTC(fromDate.year(), fromDate.month(), fromDate.date()), Date.UTC(toDate.year(), toDate.month(), toDate.date()));
                    self.timeLineCharts.push(timeLineChart1);
                }

            }, 500);

            var interval2 = setInterval(function() {
                if (self.$('.footerplaceholder').length > 0) {
                    clearInterval(interval2);
                    var timeLineChart2 = self.$('.footerplaceholder').highcharts(self.pChartOptions).highcharts();
                    timeLineChart2.xAxis[0].setExtremes(Date.UTC(fromDate.year(), fromDate.month(), fromDate.date()), Date.UTC(toDate.year(), toDate.month(), toDate.date()));
                    self.timeLineCharts.push(timeLineChart2);
                }

            }, 500);

            this.collectionViewRegion.show(this.chartsCompositeView);

            function onMouseLeaveHitArea(evt) {
                $.each(self.activeCharts, function(i, obj) {
                    obj.tooltip.hide();
                });
            }

            var cr = self.$('.crosshairs');
            var pointers = self.$('.stackedGraphPointer');

            self.$('*').not('.collectionContainer .renderTo, .highcharts-container').on('mouseover.stackedGraph', function(e) {
                pointers.css({
                    visibility: 'hidden'
                });
                // hidePointer();

                $.each(self.activeCharts, function(i, chart) {
                    chart.tooltip.hide();
                    if (chart.line) {
                        chart.line.
                        css({
                            visibility: 'hidden'
                        });

                    }
                });

            });

            self.$('.collectionContainer').on({
                'mouseover.stackedGraph': function(evt) {
                    evt.stopPropagation();
                    if (self.activeCharts.length < 1) {
                        return;
                    }

                    $.each(self.activeCharts, function(i, chart) {
                        var ev = chart.pointer.normalize(evt);
                        var mouseX = evt.pageX;
                        chart.pointer.runPointActions(ev);
                        if (chart.line) {
                            chart.line.attr({
                                x: ev.chartX
                            }).
                            css({
                                visibility: 'visible'
                            });
                        }
                    });
                },
                'mousemove.stackedGraph': function(evt) {
                    // console.log(evt.currentTarget);
                    evt.stopPropagation();
                    if (self.activeCharts.length < 1) {
                        return;
                    }

                    $.each(self.activeCharts, function(i, chart) {
                        var ev = chart.pointer.normalize(evt);
                        var mouseX = evt.pageX;
                        chart.pointer.runPointActions(ev);
                        if (chart.line) {
                            chart.line.attr({
                                x: ev.chartX
                            });
                        }

                    });

                    var chartX = self.activeCharts[0].pointer.normalize(evt);

                    pointers.text(moment(self.activeCharts[0].xAxis[0].toValue(chartX.chartX)).format('M/D/YY'));

                    var offSet = self.$('.pointerContainer').offset();
                    var mouseX = (evt.pageX - offSet.left);
                    pointers.css({
                        left: mouseX - pointers.eq(0).width(),
                        visibility: 'visible'
                    });

                }

            }, '.highcharts-container');

        },
        pChartOptions: {
            chart: {
                ignoreHiddenSeries: false,
                type: 'line',
                height: 40 //20
            },
            legend: {
                enabled: false
            },
            credits: {
                enabled: false
            },
            title: {
                text: null
            },
            subtitle: {
                text: null
            },
            xAxis: {
                type: 'datetime'
            },
            yAxis: {
                gridLineWidth: 0,
                labels: {
                    enabled: false
                },
                title: null,
                minPadding: 0,
                maxPadding: 0
            },
            plotOptions: {},
            series: [{
                data: [],
                visible: false
            }]
        },
        /*
         * this eventMapper with the attributes "refresh" and "add"
         * tied to the view's "refreshCollection" and "onClickAdd" methods
         * will enable the Applet Chrome's "refresh" and "add" buttons
         */
        eventMapper: {
            'refresh': 'refreshMethod',
            'add': 'onClickAdd'
        },
        refreshCollection: function() {
            // Example Code: clear the cached data,
            // call reset and fetch on the collection to get the updated models
            // -----------------------------------
            var collection = this.collection;

            if (collection instanceof Backbone.PageableCollection) {
                collection.fullCollection.reset();
            } else {
                collection.reset();
            }
            ADK.ResourceService.clearCache(collection.url);
            ADK.ResourceService.fetchCollection(collection.fetchOptions, collection);
            // -----------------------------------
        },
        regions: {
            collectionViewRegion: '.grid-container' //,
        },
        onDestroy: function() {

            this.$('.collectionContainer').off('.stackedGraph');
            this.$('*').not('.collectionContainer .renderTo, .highcharts-container').off('.stackedGraph');

            _.each(this.activeCharts, function(e, i) {
                e.destroy();
            });
            this.activeCharts = [];

            _.each(this.timeLineCharts, function(e, i) {
                e.destroy();
            });
            this.timeLineCharts = [];

            this.chartOptionsCollection.reset();
            // this.stackedGraphChannel.off('readyToChart');
            // this.stackedGraphChannel.off('delete');
        }

    });
});
